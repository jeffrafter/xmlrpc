require 'net/http'
require 'net/https'
require 'rexml/document'
require 'cgi'

# Register a new set of XML handlers (watch out for conflicts from other plugins?)
# For MimeType::XML
ActionController::Base.param_parsers[Mime::XML] = Proc.new do |data|
  doc = REXML::Document.new(data)
  if doc.root.name == "methodCall"
    {:rpc => XmlRpc::API::Request.new(:doc => doc)}
  else
    XmlSimple.xml_document_in(doc, 'ForceArray' => false)
  end  
end


# Classes for handling XML Based remote procedure calls according to the 
# specifications at http://www.xmlrpc.com/spec
module XmlRpc

  # Monkey patch XmlSimple: 
  #   activesupport/lib/active_support/vendor/xml-simple-1.0.11/xmlsimple.rb
  # We need a method to replicate xml_in but accept a REXML document and set the 
  # @doc, This will be called xml_document_in. This module is included in the 
  # normative XmlSimple at the bottom of this file
  module XmlSimple 
    # This is a corellary to xml_in, however it takes +doc+ instead of +string+
    # for the XML document. This assumes that the document has already been
    # parsed and should not be parsed again
    def xml_document_in(doc = nil, options = nil)
      handle_options('in', options)
      @doc = doc
      result = collapse(@doc.root)
      result = @options['keeproot'] ? merge({}, @doc.root.name, result) : result
      put_into_cache(result, filename)
      result
    end

    # This is the functional version of the instance method xml_document_in.
    def XmlSimple.xml_document_in(doc = nil, options = nil)
      xml_simple = XmlSimple.new
      xml_simple.xml_in(doc, options)
    end
  end

  module API # :nodoc:

    # Request Errors are raised when the +send_request+ invocation fails or
    # the remote server returns a 500 error. For XML RPC specific faults
    # check +XmlRpc::API::Response.error+.
    class RequestError < StandardError; end

    # Value Errors are raised when a +Message+ is parsed and an unknown value
    # type is found.
    class ValueError < StandardError; end

    # Faults can be created and raised within controller handlers to return
    # specific codes to the RPC requestor. ValueErrors have the fault_code -1 by
    # default. All other exceptions have fault_code 0 by default.
    class Fault < StandardError 
      attr_reader :fault_code
      
      def initialize(msg, code) 
        super(msg)
        @fault_code = code
      end
      
      def fault_string
        self.message
      end
      
      def build_xml(builder)
        builder.fault {
          builder.value {
            fault_struct = {:faultCode => @fault_code, :faultString => fault_string}
            XmlRpc::API::Message.build_value(builder, fault_struct)
          }
        }
      end       
    end
    
    # An XML RPC API class specifies the methods that will be available for
    # invocation for an API. It also contains metadata for calls such as the 
    # method and URL hints.
    #
    # It is not intended to be instantiated; services can be built on top of it.
    class Base

      # :nodoc:
      def initialize
      end

      # XML RPC API methods are invoked using +send_request+, which will build the 
      # appropriate URL and POST for performing the invocation on the service.
      #
      # The method input parameters is specified in +options+.
      #
      # If no method input parameter is given, the method is assumed to take no 
      # parameters
      #
      # Valid options:
      # [<tt>:url</tt>]      Service URL
      # [<tt>:method</tt>]   Method name to invoke
      # [<tt>:params</tt>]   Parameters for the method
      def self.send_request(options={})
        url = URI::parse(options.delete(:url))
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true if (url.port == 443)
        headers = { 'Content-Type' => 'text/xml' }
        request = XmlRpc::API::Request.new(options)
        response = http.request_post("#{url.path}#{url.query ? '?' + url.query : ''}", request.xml, headers)
        unless response.kind_of? Net::HTTPSuccess
          raise XmlRpc::API::RequestError, "HTTP Response: #{response.code} #{response.message}"
        end       
        XmlRpc::API::Response.new(:xml => response.body)
      end

      # A controller calls handle request and passes the parsed XMLRPC::Request.
      # The parameters are read and the request is dispatched to the appropriate
      # controller action specified as the XML RPC method
      # The controller action can handle any query parameters (including 
      # logging a user in, prior to passing the XML payload or within the 
      # action itself. Some XMLRPC methods contain illegal characters such as
      # "."; in such a case include a +method_names+ hash for lookup. The 
      # method_name_map hash is also useful for whitelisting controller methods.
      def self.handle_request(controller, request, method_name_map = {})
        # Call the appropriate controller method, based on the request's method
        method_sym = method_name_map[request.method]
        raise Fault.new("Unknown method", -2) unless method_sym
        value = controller.send(method_sym, *request.params)
        # Return the value as a response
        response = XmlRpc::API::Response.new(:value => value, :fault => nil)
      rescue Fault => f
        XmlRpc::API::Response.new(:fault => f)         
      rescue ValueError => v
        XmlRpc::API::Response.new(:fault => Fault.new(e.message, -1))         
      rescue Exception => e
        XmlRpc::API::Response.new(:fault => Fault.new(e.message + "\n" + e.backtrace.join("\n"), 0))         
      end

    end # class Base

    # An XML RPC +Message+ can be either a request or a response. This base
    # class is not intended to be instantiated, but rather derived from. For
    # specific implementations see +Request+ and +Response+. The +Message+ class 
    # also provides a class method +get_value+ that can be used for converting
    # XML RPC +<value>+ elements to ruby types.
    class Message
      # Access to the XML Document object
      attr_reader :document

      # Access to the Raw XML Document
      attr_reader :xml

      # Create a new XML RPC message. In general, you should create a +Request+
      # or +Response+ object instead of using the +Message+ object directly.
      #
      # Valid options:
      # [<tt>:xml</tt>]  XML input is in string format
      # [<tt>:doc</tt>]  XML input has already been parsed as a REXML document
      def initialize(options={})
        raise ValueError.new("You must include the an :xml or :doc option when creating a message") unless options[:xml] || options[:doc]
        if (options[:xml])
          @document = REXML::Document.new(options[:xml])
          @xml = options[:xml]
        else
          @document = options[:doc]
        end            
        
      end

      # Class method +get_value+ that can be used for converting
      # XML RPC +<value>+ elements to ruby types. If the +element+ parameter
      # is nil, the method will return nil. If a type sub-element is included
      # but unsupported it will raise a +ValueError+.
      def self.parse_value(element)                
        return nil unless element
        if element && element.elements[1]                            
          case element.elements[1].name
          when 'string'
            element.elements[1].text
          when 'i4', 'int'
            element.elements[1].text.to_i
          when 'boolean'
            element.elements[1].text == "1" || element.elements[1].text == "true" 
          when 'double'
            element.elements[1].text.to_f
          when 'dateTime.iso8601'
            DateTime.parse(element.elements[1].text)
          when 'base64'
            v = XmlRpc::API::Value.new(:base64)
            v.encoded_value = element.elements[1].text
            v
          when 'array'
            arr = Array.new
            element.elements[1].elements.each('data/value') { |e|
              arr.push self.parse_value(e) 
            }
            arr
          when 'struct'
            h = Hash.new
            element.elements[1].elements.each('member') { |e|
              h[e.elements['name'].text] = self.parse_value(e.elements['value']) 
            }
            h
          else
            raise XmlRpc::API::ValueError, "Unknown data type in value: #{element.elements[1].name}"              
          end 
        elsif element
          # If no type is specified the type is string
          element.text
        end  
      end    
      
      # Class method +build_value+ can be used for converting ruby types 
      # to XML RPC +<value>+ elements. If the +param+ parameter is nil, the 
      # method will return nil. The output XML will be appended to the +builder+
      # object that is passed
      def self.build_value(builder, param) 
        return if param.nil?      
        if (param.is_a?(TrueClass) || param.is_a?(FalseClass))
          builder.boolean "#{param}"
        elsif (param.is_a? Integer)
          builder.int "#{param}"
        elsif (param.is_a? Float)       
          builder.double "#{param}"
        elsif (param.is_a? Time)       
          builder.tag! 'dateTime.iso8601', param.iso8601
        elsif (param.is_a? DateTime)       
          builder.tag! 'dateTime.iso8601', param.strftime("%Y-%m-%dT%H:%M:%S#{param.offset == 0 ? 'Z' : '%Z'}")
        elsif (param.is_a? Date)       
          builder.tag! 'dateTime.iso8601', param.strftime("%Y-%m-%d") # abbrev iso8601 format
        elsif (param.is_a? XmlRpc::API::Value)                   
          builder.tag! 'base64', "#{param}" if param.kind == :base64
        elsif (param.is_a? Array)       
          builder.array {
            builder.data {
              param.each { |item|
                builder.value {
                  build_value(builder, item)
                } unless item.nil?
              }  
            }
          }    
        elsif (param.is_a? Hash)       
          builder.struct {
            param.each { |key,value|
              builder.member {
                builder.tag! 'name', "#{key}"
                builder.value {
                  build_value builder, value
                } 
              } unless value.nil?  
            }  
          }          
        else
          builder.string "#{param}"      
        end 
      end                                      
    end

    # +Request+ objects can be used to encapsulate an XML RPC request for 
    # receiving or sending communications
    class Request < Message
          
      # When handling a +Request+ you should create the message object with an 
      # +:xml+ option containing the XMLRPC request text. If you are building a 
      # request to be sent to a remote service, pass nil as the +:xml+ when 
      # creating, and include :method and :params options. 
      #
      # Valid options:
      # [<tt>:xml</tt>]      The request XML document
      # [<tt>:method</tt>]   Method name to invoke
      # [<tt>:params</tt>]   Parameters for the method
      # [<tt>:indent</tt>]   Indentation value to use when building the document
      def initialize(options = {})
        if ((options[:xml] || options[:doc]) && options[:method])
          raise RequestError.new("You cannot include both :xml and :method parameters")
        elsif (options[:xml] || options[:doc])
          super(options)
        elsif (options[:method] && options[:params])
          builder = Builder::XmlMarkup.new(:indent => options[:indent] || 0)
          request = builder.methodCall {
            builder.methodName options[:method]
            builder.params {
              options[:params].each { |param|
                builder.param {
                  builder.value {
                    XmlRpc::API::Message.build_value(builder, param)
                  } unless param.nil?  
                }
              }                
            }  
          }    
          super(:xml => request)
        else
          raise RequestError.new("You must include either an :xml or :doc or :method and :params options")
        end  
      end      

      # The method specified in the XML payload
      def method
        @method ||= XmlRpc::API::Message.parse_value(@document.root.elements["methodName"])
      end
      
      # The parameters specified in the XML payload
      def params
        @params ||= @document.root.get_elements("params/param").map {|e|
          XmlRpc::API::Message.parse_value(e.elements["value"])
        }  
      end
    end

    # XML RPC API methods return a +Response+, which contains the XML response
    # after performing the invocation on the service.
    class Response < Message

      # When handling a +Response+ you should create the message object with an 
      # +:xml+ option containing the XMLRPC request text. If you are building a 
      # response to be sent from your own service, pass nil as the +:xml+ when 
      # creating, and include the :params and :fault options. 
      #
      # Valid options:
      # [<tt>:xml</tt>]    The response XML document
      # [<tt>:value</tt>]  Return value
      # [<tt>:indent</tt>] Indentation value to use when building the document
      # [<tt>:fault</tt>]  A fault object to be returned in the response
      def initialize(options = {})
        if (options[:xml] && (options.has_key?(:value) || options[:fault]))
          raise RequestError.new("You cannot include both :xml and :value or :fault options")
        elsif (options[:xml])
          super(options)
        elsif (options.has_key?(:value) || options[:fault])
          builder = Builder::XmlMarkup.new(:indent => options[:indent] || 0)
          response = builder.methodResponse {
            if (options[:fault])
              options[:fault].build_xml(builder)
            else
              builder.params {
                builder.param {
                  builder.value {
                    XmlRpc::API::Message.build_value(builder, options[:value])
                  } unless options[:value].nil?  
                }
              }  
            end  
          }    
          super(:xml => response)
        else
          raise RequestError.new("You must include either an :xml or :value or :fault option")
        end  
      end      

      # Return true if request is valid.
      def is_valid?
        (self.fault_code.blank? && self.fault_string.blank?)
      end

      # The XML RPC fault code
      def fault_code
        @fault_code ||= XmlRpc::API::Message.parse_value(
          @document.root.elements["fault/value/struct/member[name='faultCode']/value"]) if @document && @document.root
      end
      
      # The XML RPC fault error 
      def fault_string
        @fault_string ||= XmlRpc::API::Message.parse_value(
          @document.root.elements["fault/value/struct/member[name='faultString']/value"]) if @document && @document.root           
      end

      # Return an error message containing the fault string and fault code if there is any error.
      def error
        "#{self.fault_string} (#{self.fault_code})" unless self.fault_code.blank?
      end
      
      # Return the response value as a Ruby typed value
      def value
        @value ||= XmlRpc::API::Message.parse_value(@document.root.elements["params/param/value"])
      end
        
    end
    
    # A wrapper for a Base 64 encoded parameter.
    # Enventually this may be expanded to work as a wrapper for all of the 
    # supported parameter types.
    class Value
      attr_reader :kind
      attr_accessor :encoded_value
    
      def initialize(kind, data=nil)
        raise ValueError.new("Unsupported value type #{kind}") unless kind == :base64
        self.encode_value(data) unless data.nil?
        @kind = kind
      end
      
      def encode_value(data)
        @encoded_value = Base64.encode64(data)      
      end
      
      def decoded_value
        Base64.decode64(@encoded_value).chomp if @encoded_value              
      end

      def to_s
        "#{@encoded_value.chomp if @encoded_value}"
      end
    end
  end
end  

XmlSimple.extend(XmlRpc::XmlSimple)