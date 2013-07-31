require 'set'

module RubyCop
  # Visitor class for Ruby::Node subclasses. Determines whether the node is
  # safe according to our rules.

  class Policy
    attr_reader :rejection

    attr_accessor :allow_while, :allow_until
    attr_reader :const_list, :call_list

    def initialize(options = {})
      strict = options.fetch(:strict) { [] }
      @const_list = GrayList.new(strict.include?(:constants))
      @call_list = GrayList.new(strict.include?(:calls))
      initialize_blacklists
    end

    def inspect
      '#<%s:0x%x>' % [self.class.name, object_id]
    end

    def blacklist_const(const)
      @const_list.blacklist(const)
    end

    def blacklist_call(call)
      @call_list.blacklist(call)
    end

    def const_allowed?(const)
      @const_list.allow?(const)
    end

    def call_allowed?(identifier)
      @call_list.allow?(identifier)
    end

    def whitelist_const(const)
      @const_list.whitelist(const)
    end

    def whitelist_call(call)
      @call_list.whitelist(call)
    end

    def visit(node)
      klass = node.class.ancestors.detect do |ancestor|
        respond_to?("visit_#{ancestor.name.split('::').last}")
      end
      if klass
        send("visit_#{klass.name.split('::').last}", node)
      else
        warn "unhandled node type: #{node.inspect}:#{node.class.name}"
        true
      end
    end

    def visit_Alias(node)
      set_rejection 'alias'
      false # never allowed
    end

    def visit_Args(node)
      node.elements.all? { |e| visit(e) }
    end

    def visit_Array(node)
      node.elements.all? { |e| visit(e) }
    end

    def visit_Assoc(node)
      visit(node.key) && visit(node.value)
    end

    def visit_Binary(node)
      visit(node.lvalue) && visit(node.rvalue)
    end

    def visit_Block(node)
      (node.params.nil? || visit(node.params)) && node.elements.all? { |e| visit(e) }
    end

    CALL_BLACKLIST = %w[
      __send__
      abort
      alias_method
      at_exit
      autoload
      binding
      callcc
      caller
      class_eval
      const_get
      const_set
      dup
      eval
      exec
      exit
      fail
      fork
      gets
      global_variables
      instance_eval
      load
      loop
      method
      module_eval
      open
      public_send
      readline
      readlines
      redo
      remove_const
      require
      retry
      send
      set_trace_func
      sleep
      spawn
      srand
      syscall
      system
      trap
      undef
      __callee__
      __method__
    ].to_set.freeze

    def visit_Call(node)
      identifier = string_from_call_identifier(node.identifier)

      if call_allowed?(identifier)
        [node.target, node.arguments, node.block].compact.all? { |e| visit(e) }
      else
        capture_rejection(false, identifier)
      end
    end

    def visit_Case(node)
      visit(node.expression) && visit(node.block)
    end

    def visit_ChainedBlock(node)
      node.elements.all? { |e| visit(e) } && node.blocks.all? { |e| visit(e) } && (node.params.nil? || visit(node.params))
    end

    def visit_Class(node)
      visit(node.const) && (node.superclass.nil? || visit(node.superclass)) && visit(node.body)
    end

    def visit_ClassVariable(node)
      set_rejection("Class Variable: #{node.token}")
      false # never allowed
    end

    def visit_ClassVariableAssignment(node)
      set_rejection("Class Variable: #{node.lvalue.token}")
      false # never allowed
    end

    def visit_Char(node)
      true
    end

    def visit_Constant(node)
      capture_rejection(const_allowed?(node.token), "Constant: #{node.token}")
    end

    def visit_ConstantAssignment(node)
      visit(node.lvalue) && visit(node.rvalue)
    end

    def visit_Defined(node)
      false # never allowed (though it's probably safe)
    end

    def visit_Else(node)
      node.elements.all? { |e| visit(e) }
    end

    def visit_ExecutableString(node)
      set_rejection('shell access e.g. (exec or backticks ``)')
      false # never allowed
    end

    def visit_Float(node)
      true
    end

    def visit_For(node)
      visit(node.variable) && visit(node.range) && visit(node.statements)
    end

    def visit_GlobalVariable(node)
      set_rejection(node.token)
      false # never allowed
    end

    def visit_GlobalVariableAssignment(node)
      set_rejection(node.lvalue.token)
      false # never allowed
    end

    def visit_Hash(node)
      node.assocs.nil? || node.assocs.all? { |e| visit(e) }
    end

    def visit_Identifier(node)
      capture_rejection call_allowed?(node.token), node.token
    end

    def visit_If(node)
      visit(node.expression) && node.elements.all? { |e| visit(e) } && node.blocks.all? { |e| visit(e) }
    end
    alias_method :visit_Unless, :visit_If

    def visit_IfMod(node)
      visit(node.expression) && node.elements.all? { |e| visit(e) }
    end
    alias_method :visit_UnlessMod, :visit_IfMod

    def visit_IfOp(node)
      visit(node.condition) && visit(node.then_part) && visit(node.else_part)
    end

    def visit_InstanceVariable(node)
      true
    end

    def visit_InstanceVariableAssignment(node)
      visit(node.rvalue)
    end

    def visit_Integer(node)
      true
    end

    KEYWORD_WHITELIST = %w[
      false
      nil
      self
      true
    ].to_set.freeze

    def visit_Keyword(node)
      KEYWORD_WHITELIST.include?(node.token)
    end

    def visit_Label(node)
      true
    end

    def visit_LocalVariableAssignment(node)
      visit(node.rvalue)
    end

    def visit_Method(node)
      [node.target, node.params, node.body].compact.all? { |e| visit(e) }
    end

    def visit_Module(node)
      visit(node.const) && visit(node.body)
    end

    def visit_MultiAssignment(node)
      visit(node.lvalue) && visit(node.rvalue)
    end

    def visit_MultiAssignmentList(node)
      node.elements.all? { |e| visit(e) }
    end

    def visit_Params(node)
      node.elements.all? { |e| visit(e) }
    end

    def visit_Program(node)
      node.elements.all? { |e| visit(e) }
    end

    def visit_Range(node)
      visit(node.min) && visit(node.max)
    end

    def visit_RescueMod(node)
      node.elements.all? { |e| visit(e) } && visit(node.expression)
    end

    def visit_RescueParams(node)
      node.elements.all? { |e| visit(e) }
    end

    def visit_SingletonClass(node)
      visit(node.superclass) && visit(node.body)
    end

    def visit_SplatArg(node)
      visit(node.arg)
    end

    def visit_Statements(node)
      node.elements.all? { |e| visit(e) }
    end

    def visit_String(node)
      # embedded strings can have statements in them, so check those
      node.elements.reject { |e| e.is_a?(::String) }.all? { |e| visit(e) }
    end

    def visit_StringConcat(node)
      node.elements.all? { |e| visit(e) }
    end

    def visit_Symbol(node)
      true
    end

    def visit_Unary(node)
      visit(node.operand)
    end

    def visit_Until(node)
      allowed = self.allow_until || false
      unless allowed
        set_rejection('until')
      end
      allowed
    end

    alias_method :visit_UntilMod, :visit_Until

    def visit_When(node)
      visit(node.expression) && node.elements.all? { |e| visit(e) }
    end

    def visit_While(node)
      allowed = self.allow_while || false
      unless allowed
        set_rejection('while')
      end
      allowed
    end

    alias_method :visit_WhileMod, :visit_While

    private

    CONST_BLACKLIST = %w[
      ARGF
      ARGV
      Array
      Base64
      Class
      Dir
      ENV
      Enumerable
      Error
      Exception
      Fiber
      File
      FileUtils
      GC
      Gem
      Hash
      IO
      IRB
      Kernel
      Module
      Net
      Object
      ObjectSpace
      OpenSSL
      OpenURI
      PLATFORM
      Proc
      Process
      RUBY_COPYRIGHT
      RUBY_DESCRIPTION
      RUBY_ENGINE
      RUBY_PATCHLEVEL
      RUBY_PLATFORM
      RUBY_RELEASE_DATE
      RUBY_VERSION
      Rails
      STDERR
      STDIN
      STDOUT
      String
      TOPLEVEL_BINDING
      Thread
      VERSION
    ].freeze

    def initialize_blacklists
      CONST_BLACKLIST.each { |const| blacklist_const(const) }
      CALL_BLACKLIST.each { |identifier| blacklist_call(identifier) }
    end

    private

    def set_rejection(keyword)
      @rejection = "Not allowed to use '#{keyword}'"
    end

    def capture_rejection(allowed, rejection)
      set_rejection(rejection) unless allowed
      allowed
    end

    def string_from_call_identifier(identifier)
      if identifier.respond_to?(:token)
        identifier.token.to_s
      else
        identifier.to_s
      end
    end
  end
end
