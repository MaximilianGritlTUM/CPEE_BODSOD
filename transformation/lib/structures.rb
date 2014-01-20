module ProcessTransformation

class Link #{{{
  attr_accessor :from, :to
  attr_reader :condition
  def initialize(from,to,cond=nil)
    @from  = from
    @to = to
    @condition = cond
  end
end #}}}

class Node #{{{ 
  @@niceid = -1
  attr_reader :id, :type, :label, :niceid, :incoming, :outgoing
  attr_reader :endpoints, :methods, :parameters
  attr_accessor :script, :script_id, :script_var
  def initialize(id,type,label,incoming,outgoing)
    @id = id
    @niceid = (@@niceid += 1)
    @type = type
    @label = label
    @endpoints = []
    @methods = []
    @script = ''
    @script_id = nil
    @script_var = 'result'
    @parameters = {}
    @incoming = incoming
    @outgoing = outgoing
  end
end # }}} 

class Struct #{{{
  def each(&a)
    @sub.each{|s| a.call(s)}
  end
  def length
    @sub.length
  end  
end #}}}

class Alternative < Array #{{{
  attr_reader :condition
  def initialize(cond)
    @condition = cond
  end
end #}}}
class Branch < Array #{{{
end #}}}

class Parallel < Struct #{{{
  include Enumerable
  attr_reader :id, :sub
  def initialize(id)
    @id = id
    @sub = []
  end
  def new_branch
    (@sub << Branch.new).last
  end
end  #}}}

class Conditional < Struct#{{{
  include Enumerable
  attr_reader :id, :sub, :type
  def initialize(id,type)
    @id = id
    @sub = []
    @type = type
  end  
  def new_branch(cond)
    (@sub << Alternative.new(cond)).last
  end
end #}}}

class Loop < Struct #{{{
  include Enumerable
  attr_reader :sub
  attr_accessor :id, :type
  def initialize(id,type)
    @id = id
    @type = type
    @sub = []
  end  
end #}}}

class Graph #{{{
  attr_reader :flow, :nodes

  def initialize
    @nodes = {}
    @flow = []
  end

  def clean_up(&bl)
    selnodes = []
    @nodes.each do |k,n|
      ret = bl.call(n)
      selnodes << n if ret
    end
    selnodes.each do |n|
      if n.incoming > 1 || n.outgoing > 1
        raise "#{n.inspect} - not a simple node to remove"
      end  
      to,from = nil
      @flow.each do |f|
        to = f if f.to == n.id
        from = f if f.from == n.id
      end
      if to && from
        to.to = from.to
        @flow.delete(from)
        @nodes.delete(n.id)
      else
        raise "#{n.inspect} - could not remove flow"
      end  
    end
  end

  def find_script_id(s)
    @nodes.find_all{|k,n| n.script_id == s}
  end

  def add_node(n)
    @nodes[n.id] = n
  end  

  def incoming_condition(n)
    @flow.find_all { |x| x.to == n.id }
  end

  def add_flow(l)
    @flow << l
  end

  def next_nodes(from)
    links = @flow.find_all { |x| x.from == from.id }
    links.map{|x| @nodes[x.to] }
  end

  def next_node(from)
    if (nodes = next_nodes(from)).length == 1
      nodes.first
    else
      raise "#{from.inspect} - multiple outgoing connections"
    end  
  end
end #}}}

  class Tree < Array
    def to_s
      "ROOT\n" << print_tree(self)
    end

    def print_tree(ele,indent=2,last=false)
      ret = ''
      ele.each_with_index do |e,i|
        pchar = i == ele.length - 1 ? '└' : '├'
        if e.is_a?(Node)
          ret << (' ' * indent) + pchar + ' ' + e.niceid.to_s + "\n"
        else
          ret << (' ' * indent) + pchar + ' ' + e.class.to_s + "\n"
          ret << print_tree(e,indent+2,i == ele.length - 1)
        end
      end
      ret
    end
    private :print_tree
  end

  class Traces
    def initialize(start)
      @sub = start
    end

    def initialize_copy(other)
     super
     @sub.map{ |t| t.dup }
    end

    def first_node
      @sub.first.first
    end

    def first
      @sub.first
    end

    def last
      @sub.last
    end

    def shift
      @sub.each{ |tr| tr.shift }
    end

    def <<(e)
      @sub << e
    end

    def to_s
      @sub.collect { |t| t.map{|n| n.niceid }.inspect }.join("\n")
    end

    def finished?
      @sub.reduce(0){|sum,t| sum += t.length} == 0
    end

    def group_by_first
      @sub.group_by{|t| t.first}.map{|k,v| Traces.new(v) }
    end
  end

end
