# This file is part of CPEE.
#
# CPEE is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# CPEE is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# CPEE (file COPYING in the main directory).  If not, see
# <http://www.gnu.org/licenses/>.

require 'fileutils'
if Module.const_defined?(:CPEE) && CPEE.const_defined?(:DEVELOP) && CPEE::DEVELOP.const_defined?(:RIDDL)
  require File.join(CPEE::DEVELOP::RIDDL,'riddl/server')
  require File.join(CPEE::DEVELOP::RIDDL,'riddl/client')
  require File.join(CPEE::DEVELOP::RIDDL,'riddl/utils/notifications_producer')
  require File.join(CPEE::DEVELOP::RIDDL,'riddl/utils/properties')
else
  require 'riddl/server'
  require 'riddl/client'
  require 'riddl/utils/notifications_producer'
  require 'riddl/utils/properties'
end
require_relative 'controller'

require 'ostruct'
class ParaStruct < OpenStruct
  def to_json(*a)
    table.to_json
  end
end
def →(a); ParaStruct.new(a); end
def ⭐(a); ParaStruct.new(a); end

module CPEE

  SERVER = File.expand_path(File.join(__dir__,'..','cpee.xml'))

  def self::implementation(opts)
    opts[:instances]                  ||= File.expand_path(File.join(__dir__,'..','..','server','instances'))
    opts[:global_handlerwrappers]     ||= File.expand_path(File.join(__dir__,'..','..','server','handlerwrappers'))
    opts[:handlerwrappers]            ||= ''
    opts[:topics]                     ||= File.expand_path(File.join(__dir__,'..','..','server','resources','topics.xml'))
    opts[:properties_init]            ||= File.expand_path(File.join(__dir__,'..','..','server','resources','properties.init'))
    opts[:properties_schema_active]   ||= File.expand_path(File.join(__dir__,'..','..','server','resources','properties.schema.active'))
    opts[:properties_schema_finished] ||= File.expand_path(File.join(__dir__,'..','..','server','resources','properties.schema.finished'))
    opts[:properties_schema_inactive] ||= File.expand_path(File.join(__dir__,'..','..','server','resources','properties.schema.inactive'))
    opts[:transformation_dslx]        ||= File.expand_path(File.join(__dir__,'..','..','server','resources','transformation_dslx.xsl'))
    opts[:transformation_service]     ||= File.expand_path(File.join(__dir__,'..','..','server','resources','transformation.xml'))
    opts[:empty_dslx]                 ||= File.expand_path(File.join(__dir__,'..','..','server','resources','empty_dslx.xml'))
    opts[:notifications_init]         ||= File.expand_path(File.join(__dir__,'..','..','server','resources','notifications'))
    opts[:infinite_loop_stop]         ||= 10000

    opts[:runtime_cmds]               << [
      "startclean", "Delete instances before starting.", Proc.new { |status|
        Dir.glob(File.expand_path(File.join(opts[:instances],'*'))).each do |d|
          FileUtils.rm_r(d) if File.basename(d) =~ /^\d+$/
        end
      }
    ]

    Proc.new do
      Dir[opts[:global_handlerwrappers] + "/*.rb"].each do |h|
        require h
      end unless opts[:global_handlerwrappers].strip == ''
      Dir[opts[:handlerwrappers] + "/*.rb"].each do |h|
        require h
      end unless opts[:handlerwrappers].strip == ''

      controller = {}
      Dir[File.join(opts[:instances],'*','properties.xml')].each do |e|
        id = ::File::basename(::File::dirname(e))
        (controller[id.to_i] = (Controller.new(id,opts)) rescue nil)
      end

      interface 'properties' do |r|
        id = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1].to_i
        use Riddl::Utils::Properties::implementation(controller[id].properties, PropertiesHandler.new(controller[id]), opts[:mode]) if controller[id]
      end

      interface 'main' do
        run CPEE::Instances, controller if get '*'
        run CPEE::NewInstance, controller, opts if post 'instance-new'
        on resource do |r|
          run CPEE::Info, controller if get
          run CPEE::DeleteInstance, controller, opts if delete
          on resource 'console' do
            run CPEE::ConsoleUI, controller if get
            run CPEE::Console, controller if get 'cmdin'
          end
          on resource 'callbacks' do
            run CPEE::Callbacks, controller, opts if get
            on resource do
              run CPEE::ExCallback, controller if get || put || post || delete
            end
          end
        end
      end

      interface 'notifications' do |r|
        id = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1].to_i
        use Riddl::Utils::Notifications::Producer::implementation(controller[id].notifications, NotificationsHandler.new(controller[id]), opts[:mode]) if controller[id]
      end
    end
  end

  class ExCallback < Riddl::Implementation #{{{
    def response
      controller = @a[0]
      id = @r[0].to_i
      callback = @r[2]
      controller[id].mutex.synchronize do
        if controller[id].callbacks.has_key?(callback)
          controller[id].callbacks[callback].callback(@p,@h)
        else
          @status = 503
        end
      end
    end
  end #}}}

  class Callbacks < Riddl::Implementation #{{{
    def response
      controller = @a[0]
      opts = @a[1]
      id = @r[0].to_i
      unless controller[id]
        @status = 400
        return
      end
      Riddl::Parameter::Complex.new("info","text/xml") do
        cb = XML::Smart::string("<callbacks details='#{opts[:mode]}'/>")
        if opts[:mode] == :debug
          controller[id].callbacks.each do |k,v|
            cb.root.add("callback",{"id" => k},"[#{v.protocol.to_s}] #{v.info}")
          end
        end
        cb.to_s
      end
    end
  end #}}}

  class Instances < Riddl::Implementation #{{{
    def response
      controller = @a[0]
      Riddl::Parameter::Complex.new("wis","text/xml") do
        ins = XML::Smart::string('<instances/>')
        controller.sort{|a,b| b[0] <=> a[0] }.each do |k,v|
          ins.root.add('instance', v.info,  'uuid' => v.uuid, 'id' => k, 'state' => v.state, 'state_changed' => v.state_changed )
        end
        ins.to_s
      end
    end
  end #}}}

  class NewInstance < Riddl::Implementation #{{{
    def response
      controller = @a[0]
      opts = @a[1]
      name = @p[0].value
      id = controller.keys.sort.last.to_i

      while true
        id += 1
        unless Dir.exists? opts[:instances] + "/#{id}"
          Dir.mkdir(opts[:instances] + "/#{id}") rescue nil
          break
        end
      end

      controller[id] = Controller.new(id,opts)
      controller[id].info = name
      controller[id].state_change!

      Riddl::Parameter::Simple.new("id", id)
    end
  end #}}}

  class Info < Riddl::Implementation #{{{
    def response
      controller = @a[0]
      id = @r[0].to_i
      unless controller[id]
        @status = 400
        return
      end
      Riddl::Parameter::Complex.new("info","text/xml") do
        i = XML::Smart::string <<-END
          <info instance='#{@r[0]}'>
            <notifications/>
            <properties/>
            <callbacks/>
          </info>
        END
        i.to_s
      end
    end
  end #}}}

  class ConsoleUI < Riddl::Implementation #{{{
    def response
      controller = @a[0]
      id = @r[0].to_i
      unless controller[id]
        @status = 400
        return
      end
      Riddl::Parameter::Complex.new("res","text/html") do
        <<-END
          <!DOCTYPE html>
          <html>
            <head>
              <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
              <title>Instance Web Console</title>
              <style type="text/css">
                [contenteditable] { display: inline; }
                [contenteditable]:focus { outline: 0px solid transparent; }
                body{ font-family: Courier,Courier New,Monospace}
              </style>
              <script type="text/javascript" src="//#{controller[id].host}/js_libs/jquery.min.js"></script>
              <script type="text/javascript" src="//#{controller[id].host}/js_libs/ansi_up.js"></script>
              <script type="text/javascript" src="//#{controller[id].host}/js_libs/console.js"></script>
            </head>
            <body>
              <p>Instance Web Console. Type "help" to get started.</p>
              <div class="console-line" id="console-template" style="display: none">
                <strong>console$&nbsp;</strong><div class='edit' contenteditable="true" ></div>
              </div>
              <div class="console-line">
                <strong>console$&nbsp;</strong><div class='edit' contenteditable="true"></div>
              </div>
            </body>
          </html>
        END
      end
    end
  end #}}}
  class Console < Riddl::Implementation #{{{
    def response
      controller = @a[0]
      id = @r[0].to_i
      unless controller[id]
        @status = 400
        return
      end
      Riddl::Parameter::Complex.new("res","text/plain") do
        controller[id].console(@p[0].value)
      end
    end
  end #}}}

  class DeleteInstance < Riddl::Implementation #{{{
    def response
      controller = @a[0]
      opts = @a[1]
      id = @r[0].to_i
      unless controller[id]
        @status = 400
        return
      end
      controller.delete(id)
      FileUtils.rm_r(opts[:instances] + "/#{@r[0]}")
    end
  end #}}}

end
