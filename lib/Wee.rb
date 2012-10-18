require 'thread'

# OMG!111! strings have to be emptied
class String # {{{
  def clear
      self.slice!(0..-1)
  end
end # }}}

class Wee
  def initialize(*args)# {{{
    @wfsource = nil
    @dslr = DSLRealization.new
    @dslr.__wee_handlerwrapper_args = args
      
    ### 1.8
    initialize_search if methods.include?('initialize_search')
    initialize_data if methods.include?('initialize_data')
    initialize_endpoints if methods.include?('initialize_endpoints')
    initialize_handlerwrapper if methods.include?('initialize_handlerwrapper')
    initialize_control if methods.include?('initialize_control')
    ### 1.9
    initialize_search if methods.include?(:initialize_search)
    initialize_data if methods.include?(:initialize_data)
    initialize_endpoints if methods.include?(:initialize_endpoints)
    initialize_handlerwrapper if methods.include?(:initialize_handlerwrapper)
    initialize_control if methods.include?(:initialize_control)
  end # }}}

  module Signal # {{{
    class SkipManipulate < Exception; end
    class StopSkipManipulate < Exception; end
    class Stop < Exception; end
    class Proceed < Exception; end
    class NoLongerNecessary < Exception; end
  end # }}}

  class ManipulateRealization # {{{
    def initialize(data,endpoints,status)
      @__wee_data = data
      @__wee_endpoints = endpoints
      @__wee_status = status
      @changed_status = status.id
      @changed_data = []
      @changed_endpoints = []
    end

    attr_reader :changed_data, :changed_endpoints

    def changed_status
      @changed_status != status.id
    end

    def data
      ManipulateHash.new(@__wee_data,@changed_data)
    end
    def endpoints
      ManipulateHash.new(@__wee_endpoints,@changed_endpoints)
    end
    def status
      @__wee_status
    end
  end # }}}
  class ManipulateHash # {{{
    def initialize(values,what)
      @__wee_values = values
      @__wee_what = what
    end

    def delete(value)
      if @__wee_values.has_key?(value)
        @__wee_what << value
        @__wee_values.delete(value)
      end  
    end

    def clear
      @__wee_what += @__wee_values.keys
      @__wee_values.clear
    end

    def method_missing(name,*args)
      
      if args.empty? && @__wee_values.has_key?(name)
        @__wee_values[name] 
      elsif name.to_s[-1..-1] == "=" && args.length == 1
        temp = name.to_s[0..-2]
        @__wee_what << temp.to_sym
        @__wee_values[temp.to_sym] = args[0]
      elsif name.to_s == "[]=" && args.length == 2  
        @__wee_values[args[0]] = args[1] 
      elsif name.to_s == "[]" && args.length == 1
        @__wee_values[args[0]]
      else
        nil
      end
    end
  end # }}}

  class Status #{{{
    def initialize(id,message)
      @id        = id
      @message   = message
    end
    def update(id,message)
      @id        = id
      @message   = message
    end
    attr_reader :id, :message
  end #}}}
  
  class ReadHash # {{{
    def initialize(values)
      @__wee_values = values
    end

    def method_missing(name,*args)
      temp = nil
      if args.empty? && @__wee_values.has_key?(name)
        @__wee_values[name] 
        #TODO dont let user change stuff
      else
        nil
      end
    end
  end # }}}

  class HandlerWrapperBase # {{{
    def initialize(arguments,endpoint=nil,position=nil,continue=nil); end

    def activity_handle(passthrough, endpoint, parameters); end

    def activity_result_value; end
    def activity_result_status; end

    def activity_stop; end
    def activity_passthrough_value; end

    def activity_no_longer_necessary; end

    def inform_activity_done; end
    def inform_activity_manipulate; end
    def inform_activity_failed(err); end

    def inform_syntax_error(err,code); end
    def inform_manipulate_change(status,data,endpoints); end
    def inform_position_change(ipc); end
    def inform_state_change(newstate); end
    
    def vote_sync_before; true; end
    def vote_sync_after; true; end

    def callback(result); end
  end  # }}}

  class Position # {{{
    attr_reader :position
    attr_accessor :detail, :passthrough
    def initialize(position, detail=:at, passthrough=nil) # :at or :after or :unmark
      @position = position
      @detail = detail
      @passthrough = passthrough
    end
  end # }}}

   class Continue #{{{
     def initialize
       @thread = Thread.new{Thread.stop}
     end  
     def waiting?
       @thread.alive?
     end  
     def continue
       while @thread.status != 'sleep' && @thread.alive?
         Thread.pass
       end
       @thread.wakeup if @thread.alive? 
     end
     def wait
       @thread.join
     end
   end #}}}

  def self::search(wee_search)# {{{
    define_method :initialize_search do 
      self.search wee_search
    end
  end # }}}
  def self::endpoint(new_endpoints)# {{{
    @@__wee_new_endpoints ||= {}
    @@__wee_new_endpoints.merge! new_endpoints
    define_method :initialize_endpoints do
      @@__wee_new_endpoints.each do |name,value|
        @dslr.__wee_endpoints[name.to_s.to_sym] = value
      end
    end
  end # }}}
  def self::data(data_elements)# {{{
    @@__wee_new_data_elements ||= {}
    @@__wee_new_data_elements.merge! data_elements
    define_method :initialize_data do
      @@__wee_new_data_elements.each do |name,value|
        @dslr.__wee_data[name.to_s.to_sym] = value
      end
    end
  end # }}}
  def self::handlerwrapper(aClassname, *args)# {{{
    define_method :initialize_handlerwrapper do 
      self.handlerwrapper = aClassname
      self.handlerwrapper_args = args unless args.empty?
    end
  end # }}} 
  def self::control(flow, &block)# {{{
    @@__wee_control_block = block
    define_method :initialize_control do
      self.description(&(@@__wee_control_block))
    end
  end #  }}}
  def self::flow #{{{
  end #}}}

  class DSLRealization # {{{
    def initialize
      @__wee_search_positions = {}
      @__wee_positions = Array.new
      @__wee_main = nil
      @__wee_data ||= Hash.new
      @__wee_endpoints ||= Hash.new
      @__wee_handlerwrapper = HandlerWrapperBase
      @__wee_handlerwrapper_args = []
      @__wee_state = :ready
      @__wee_status = Status.new(0,"undefined")
    end
    attr_accessor :__wee_search_positions, :__wee_positions, :__wee_main, :__wee_data, :__wee_endpoints, :__wee_handlerwrapper, :__wee_handlerwrapper_args
    attr_reader :__wee_state, :__wee_status

    # DSL-Construct for an atomic activity
    # position: a unique identifier within the wf-description (may be used by the search to identify a starting point
    # type:
    #   - :manipulate - just yield a given block
    #   - :call - order the handlerwrapper to perform a service call
    # endpoint: (only with :call) ep of the service
    # parameters: (only with :call) service parameters
    def activity(position, type, endpoint=nil, *parameters, &blk)# {{{
      position = __wee_position_test position
      begin
        searchmode = __wee_is_in_search_mode(position)
        return if searchmode == true
        return if self.__wee_state == :stopping || self.__wee_state == :stopped || Thread.current[:nolongernecessary]

        Thread.current[:continue] = Continue.new
        handlerwrapper = @__wee_handlerwrapper.new @__wee_handlerwrapper_args, @__wee_endpoints[endpoint], position, Thread.current[:continue]

        ipc = {}
        if searchmode == :after
          wp = Wee::Position.new(position, :after, nil)
          ipc[:after] = [wp.position]
        else  
          if Thread.current[:branch_parent] && Thread.current[:branch_parent][:branch_position]
            @__wee_positions.delete Thread.current[:branch_parent][:branch_position]
            ipc[:unmark] ||= []
            ipc[:unmark] << Thread.current[:branch_parent][:branch_position].position rescue nil
            Thread.current[:branch_parent][:branch_position] = nil
          end  
          if Thread.current[:branch_position]
            @__wee_positions.delete Thread.current[:branch_position]
            ipc[:unmark] ||= []
            ipc[:unmark] << Thread.current[:branch_position].position rescue nil
          end  
          wp = Wee::Position.new(position, :at, nil)
          ipc[:at] = [wp.position]
        end
        @__wee_positions << wp
        Thread.current[:branch_position] = wp

        handlerwrapper.inform_position_change(ipc)

        # searchmode position is after, jump directly to vote_sync_after
        raise Signal::Proceed if searchmode == :after

        raise Signal::Stop unless handlerwrapper.vote_sync_before

        case type
          when :manipulate
            if block_given?
              handlerwrapper.inform_activity_manipulate
              mr = ManipulateRealization.new(@__wee_data,@__wee_endpoints,@__wee_status)
              status = nil
              parameters.delete_if do |para|
                status = para if para.is_a?(Status)
                para.is_a?(Status)
              end
              case blk.arity
                when 1; mr.instance_exec(parameters,&blk)
                when 2; mr.instance_exec(parameters,status,&blk)
                else
                  mr.instance_eval(&blk)
              end
              handlerwrapper.inform_manipulate_change(
                (mr.changed_status ? @__wee_status : nil), 
                (mr.changed_data.any? ? mr.changed_data.uniq : nil),
                (mr.changed_endpoints.any? ? mr.changed_endpoints.uniq : nil)
              )
              handlerwrapper.inform_activity_done
              wp.detail = :after
              handlerwrapper.inform_position_change :after => [wp.position]
            end  
          when :call
            params = { }
            passthrough = @__wee_search_positions[position] ? @__wee_search_positions[position].passthrough : nil
            parameters.each do |p|
              if p.class == Hash && parameters.length == 1
                params = p
              else  
                if !p.is_a?(Symbol) || !@__wee_data.include?(p)
                  raise("not all passed parameters are data elements")
                end
                params[p] = @__wee_data[p]
              end
            end
            # handshake call and wait until it finished
            handlerwrapper.activity_handle passthrough, params
            Thread.current[:continue].wait unless Thread.current[:nolongernecessary] || self.__wee_state == :stopping || self.__wee_state == :stopped

            if Thread.current[:nolongernecessary]
              handlerwrapper.activity_no_longer_necessary 
              raise Signal::NoLongerNecessary
            end  
            if self.__wee_state == :stopping
              handlerwrapper.activity_stop
              wp.passthrough = handlerwrapper.activity_passthrough_value
            end  

            if wp.passthrough.nil? && block_given?
              handlerwrapper.inform_activity_manipulate
              mr = ManipulateRealization.new(@__wee_data,@__wee_endpoints,@__wee_status)
              status = handlerwrapper.activity_result_status
              case blk.arity
                when 1; mr.instance_exec(handlerwrapper.activity_result_value,&blk)
                when 2; mr.instance_exec(handlerwrapper.activity_result_value,(status.is_a?(Status)?status:nil),&blk)
                else
                  mr.instance_eval(&blk)
              end  
              handlerwrapper.inform_manipulate_change(
                (mr.changed_status ? @__wee_status : nil), 
                (mr.changed_data.any? ? mr.changed_data.uniq : nil),
                (mr.changed_endpoints.any? ? mr.changed_endpoints.uniq : nil)
              )
            end
            if wp.passthrough.nil?
              handlerwrapper.inform_activity_done
              wp.detail = :after
              handlerwrapper.inform_position_change :after => [wp.position]
            end  
        end
        raise Signal::Proceed
      rescue Signal::SkipManipulate, Signal::Proceed
        if self.__wee_state != :stopping && !handlerwrapper.vote_sync_after
          self.__wee_state = :stopping
          wp.detail = :unmark
        end
      rescue Signal::NoLongerNecessary
        @__wee_positions.delete wp
        Thread.current[:branch_position] = nil
        wp.detail = :unmark
        handlerwrapper.inform_position_change :unmark => [wp.position]
      rescue Signal::StopSkipManipulate, Signal::Stop
        self.__wee_state = :stopping
      rescue => err
        handlerwrapper.inform_activity_failed err
        self.__wee_state = :stopping
      end
    end # }}}
    
    # Parallel DSL-Construct
    # Defines Workflow paths that can be executed parallel.
    # May contain multiple branches (parallel_branch)
    def parallel(type=nil)# {{{
      return if self.__wee_state == :stopping || self.__wee_state == :stopped || Thread.current[:nolongernecessary]

      Thread.current[:branches] = []
      Thread.current[:branch_finished_count] = 0
      Thread.current[:branch_event] = Continue.new
      Thread.current[:mutex] = Mutex.new
      yield

      Thread.current[:branch_wait_count] = (type.is_a?(Hash) && type.size == 1 && type[:wait] != nil && (type[:wait].is_a?(Integer)) ? type[:wait] : Thread.current[:branches].size)
      Thread.current[:branches].each do |thread| 
        while thread.status != 'sleep' && thread.alive?
          Thread.pass
        end
        # decide after executing block in parallel cause for coopis
        # it goes out of search mode while dynamically counting branches
        if Thread.current[:branch_search] == false
          thread[:branch_search] = false
        end  
        thread.wakeup if thread.alive?
      end

      Thread.current[:branch_event].wait
      #Thread.current[:branch_event] = nil

      unless self.__wee_state == :stopping || self.__wee_state == :stopped
        # first set all to no_longer_neccessary
        Thread.current[:branches].each do |thread| 
          if thread.alive? 
            thread[:nolongernecessary] = true
            __wee_recursive_continue(thread)
          end  
        end
        # wait for all
        Thread.current[:branches].each do |thread| 
          __wee_recursive_join(thread)
        end
      end
    end # }}}

    # Defines a branch of a parallel-Construct
    def parallel_branch(*vars)# {{{
      return if self.__wee_state == :stopping || self.__wee_state == :stopped || Thread.current[:nolongernecessary]
      branch_parent = Thread.current
      Thread.current[:branches] << Thread.new(*vars) do |*local|
        branch_parent[:mutex].synchronize do
          Thread.current.abort_on_exception = true
          Thread.current[:branch_status] = false
          Thread.current[:branch_parent] = branch_parent
          if branch_parent[:alternative_executed] && branch_parent[:alternative_executed].length > 0
            Thread.current[:alternative_executed] = [branch_parent[:alternative_executed].last]
          end
        end  

        Thread.stop
        yield(*local)

        branch_parent[:mutex].synchronize do
          Thread.current[:branch_status] = true
          branch_parent[:branch_finished_count] += 1
          if branch_parent[:branch_finished_count] == branch_parent[:branch_wait_count] && self.__wee_state != :stopping
            branch_parent[:branch_event].continue
          end  
        end  
        if self.__wee_state != :stopping && self.__wee_state != :stopped
          if Thread.current[:branch_position]
            @__wee_positions.delete Thread.current[:branch_position]
            begin
              ipc = {}
              ipc[:unmark] = [Thread.current[:branch_position].position]
              handlerwrapper = @__wee_handlerwrapper.new @__wee_handlerwrapper_args
              handlerwrapper.inform_position_change(ipc)
            end rescue nil
            Thread.current[:branch_position] = nil
          end  
        end  
      end
      Thread.pass
    end # }}}

    # Choose DSL-Construct
    # Defines a choice in the Workflow path.
    # May contain multiple execution alternatives
    def choose # {{{
      return if self.__wee_state == :stopping || self.__wee_state == :stopped || Thread.current[:nolongernecessary]
      Thread.current[:alternative_executed] ||= []
      Thread.current[:alternative_executed] << false
      yield
      Thread.current[:alternative_executed].pop
      nil
    end # }}}

    # Defines a possible choice of a choose-Construct
    # Block is executed if condition == true or
    # searchmode is active (to find the starting position)
    def alternative(condition)# {{{
      return if self.__wee_state == :stopping || self.__wee_state == :stopped || Thread.current[:nolongernecessary]
      yield if __wee_is_in_search_mode || condition
      Thread.current[:alternative_executed][-1] = true if condition
    end # }}}
    def otherwise # {{{
      return if self.__wee_state == :stopping || self.__wee_state == :stopped || Thread.current[:nolongernecessary]
      yield if __wee_is_in_search_mode || !Thread.current[:alternative_executed].last
    end # }}}

    # Defines a critical block (=Mutex)
    def critical(id)# {{{
      @__wee_critical ||= Mutex.new
      semaphore = nil
      @__wee_critical.synchronize do
        @__wee_critical_sections ||= {}
        semaphore = @__wee_critical_sections[id] ? @__wee_critical_sections[id] : Mutex.new
        @__wee_critical_sections[id] = semaphore if id
      end
      semaphore.synchronize do
        yield
      end
    end # }}}

    # Defines a Cycle (loop/iteration)
    def loop(condition)# {{{
      unless condition.is_a?(Array) && condition[0].is_a?(Proc) && [:pre_test,:post_test].include?(condition[1])
        raise "condition must be called pre_test{} or post_test{}"
      end
      return if self.__wee_state == :stopping || self.__wee_state == :stopped || Thread.current[:nolongernecessary]
      if __wee_is_in_search_mode
        yield
        return if __wee_is_in_search_mode
      end  
      case condition[1]
        when :pre_test
          yield while condition[0].call && self.__wee_state != :stopping && self.__wee_state != :stopped
        when :post_test
          begin; yield; end while condition[0].call && self.__wee_state != :stopping && self.__wee_state != :stopped
      end
    end # }}}

    def pre_test(&blk)# {{{
      [blk, :pre_test]
    end # }}}
    def post_test(&blk)# {{{
      [blk, :post_test]
    end # }}}

    def status # {{{
      @__wee_status
    end # }}}
    def data # {{{
      ReadHash.new(@__wee_data)
    end # }}}
    def endpoints # {{{
      ReadHash.new(@__wee_endpoints)
    end # }}}

  private
    def __wee_recursive_print(thread,indent='')# {{{
      p "#{indent}#{thread}"
      if thread[:branches]
        thread[:branches].each do |b|
          __wee_recursive_print(b,indent+'  ')
        end
      end  
    end  # }}}
    def __wee_recursive_continue(thread)# {{{
      return unless thread
      if thread.alive? && thread[:continue] && thread[:continue].waiting?
        thread[:continue].continue
      end
      if thread.alive? && thread[:branch_event] && thread[:branch_event].waiting?
        thread[:mutex].synchronize do
          unless thread[:branch_event].nil?
            thread[:branch_event].continue
            # thread[:branch_event] = nil
          end  
        end  
      end  
      if thread[:branches]
        thread[:branches].each do |b|
          __wee_recursive_continue(b)
        end
      end  
    end  # }}}
    def __wee_recursive_join(thread)# {{{
      return unless thread
      if thread.alive? && thread != Thread.current
        thread.join
      end
      if thread[:branches]
        thread[:branches].each do |b|
          __wee_recursive_join(b)
        end
      end  
    end  # }}}

    def __wee_position_test(position)# {{{
      if position.is_a?(Symbol) && position.to_s =~ /[a-zA-Z][a-zA-Z0-9_]*/
        position
      else   
        self.__wee_state = :stopping
        handlerwrapper = @__wee_handlerwrapper.new @__wee_handlerwrapper_args
        handlerwrapper.inform_syntax_error(Exception.new("position (#{position}) not valid"),nil)
      end
    end # }}}

    def __wee_is_in_search_mode(position = nil)# {{{
      branch = Thread.current
      return false if @__wee_search_positions.empty? || branch[:branch_search] == false

      if position && @__wee_search_positions.include?(position) # matching searchpos => start execution from here
        branch[:branch_search] = false # execute all activities in THIS branch (thread) after this point
        while branch.key?(:branch_parent) # also all parent branches should execute activities after this point, additional branches spawned by parent branches should still be in search mode
          branch = branch[:branch_parent]
          branch[:branch_search] = false
        end
        @__wee_search_positions[position].detail == :after ? :after : false
      else  
        branch[:branch_search] = true
      end  
    end # }}}
  
  public
    def __wee_finalize
      __wee_recursive_join(@__wee_main)
      @__wee_state = :stopped
      handlerwrapper = @__wee_handlerwrapper.new @__wee_handlerwrapper_args
      handlerwrapper.inform_state_change @__wee_state
    end

    def __wee_state=(newState)# {{{
      return @__wee_state if newState == @__wee_state
      @__wee_positions = Array.new if @__wee_state != newState && newState == :running
      handlerwrapper = @__wee_handlerwrapper.new @__wee_handlerwrapper_args
      @__wee_state = newState

      if newState == :stopping
        __wee_recursive_continue(@__wee_main)
      end
  
      handlerwrapper.inform_state_change @__wee_state
    end # }}}

  end # }}}

public
  def positions # {{{
    @dslr.__wee_positions
  end # }}}

  # set the handlerwrapper
  def handlerwrapper # {{{
    @dslr.__wee_handlerwrapper
  end # }}}
  def handlerwrapper=(new_wee_handlerwrapper) # {{{
    superclass = new_wee_handlerwrapper
    while superclass
      check_ok = true if superclass == Wee::HandlerWrapperBase
      superclass = superclass.superclass
    end
    raise "Handlerwrapper is not inherited from HandlerWrapperBase" unless check_ok
    @dslr.__wee_handlerwrapper = new_wee_handlerwrapper
  end # }}}

  # Get/Set the handlerwrapper arguments
  def handlerwrapper_args # {{{
    @dslr.__wee_handlerwrapper_args
  end # }}} 
  def handlerwrapper_args=(args) # {{{
    if args.class == Array
      @dslr.__wee_handlerwrapper_args = args
    end
    nil
  end #  }}}

  # Get the state of execution (ready|running|stopping|stopped|finished)
  def state # {{{
    @dslr.__wee_state
  end #  }}}

  # Set search positions
  # set new_wee_search to a boolean (or anything else) to start the process from beginning (reset serach positions)
  def search(new_wee_search=false) # {{{
    @dslr.__wee_search_positions.clear

    new_wee_search = [new_wee_search] if new_wee_search.is_a?(Position)

    if !new_wee_search.is_a?(Array) || new_wee_search.empty?
      false
    else  
      new_wee_search.each do |search_position| 
        @dslr.__wee_search_positions[search_position.position] = search_position
      end  
      true
    end
  end # }}}
  
  def data(new_data=nil) # {{{
    unless new_data.nil? || !new_data.is_a?(Hash)
      new_data.each{|k,v|@dslr.__wee_data[k] = v}
    end
    @dslr.__wee_data
  end # }}}
  def endpoints(new_endpoints=nil) # {{{
    unless new_endpoints.nil? || !new_endpoints.is_a?(Hash)
      new_endpoints.each{|k,v|@dslr.__wee_endpoints[k] = v}
    end
    @dslr.__wee_endpoints
  end # }}}
  def endpoint(new_endpoints) # {{{
    unless new_endpoints.nil? || !new_endpoints.is_a?(Hash) || !new_endpoints.length == 1
      new_endpoints.each{|k,v|@dslr.__wee_endpoints[k] = v}
    end
    nil
  end # }}}
  def status # {{{
    @dslr.__wee_status
  end # }}}

  # get/set workflow description
  def description(code = nil,&blk) # {{{
    bgiven = block_given?
    if code.nil? && !bgiven
      @wfsource
    else
      @wfsource = code unless bgiven
      (class << self; self; end).class_eval do
        define_method :__wee_control_flow do
          @dslr.__wee_positions.clear
          @dslr.__wee_state = :running
          begin
            if bgiven
              @dslr.instance_eval(&blk)
            else
              @dslr.instance_eval(code)
            end  
          rescue Exception => err
            @dslr.__wee_state = :stopping
            handlerwrapper = @dslr.__wee_handlerwrapper.new @dslr.__wee_handlerwrapper_args
            handlerwrapper.inform_syntax_error(err,code)
          end
          if @dslr.__wee_state == :running
            @dslr.__wee_state = :finished 
            ipc = { :unmark => [] }
            @dslr.__wee_positions.each{|wp| ipc[:unmark] << wp.position}
            @dslr.__wee_positions.clear
            handlerwrapper = @dslr.__wee_handlerwrapper.new @dslr.__wee_handlerwrapper_args
            handlerwrapper.inform_position_change(ipc)
          end 
          if @dslr.__wee_state == :stopping
            @dslr.__wee_finalize
          end
        end
      end
      bgiven ? blk : code
    end
  end # }}}

  # Stop the workflow execution
  def stop # {{{
    Thread.new do
      @dslr.__wee_state = :stopping
      @dslr.__wee_main.join if @dslr.__wee_main
    end  
  end # }}}
  # Start the workflow execution
  def start # {{{
    return nil if @dslr.__wee_state != :ready && @dslr.__wee_state != :stopped
    @dslr.__wee_main = Thread.new do
      __wee_control_flow
    end
  end # }}}

end
