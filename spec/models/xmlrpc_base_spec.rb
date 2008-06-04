require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/../../lib/xmlrpc'

class TestController
  def add(left, right) 
    left + right
  end
  
  def crash(message)
    raise "Error: #{message}" 
  end
  
  def get_state_name(index)
    return "South Dakota" if index == 41
  end
end


describe "XmlRpc", "API", "Base" do
  
  it "should handle a request" do
    r = XmlRpc::API::Base.handle_request(TestController.new, '<methodCall>
      <methodName>add</methodName>
      <params>
        <param><value><int>1</int></value></param>
        <param><value><int>2</int></value></param>
      </params>
    </methodCall>', {'add' => :add}) #"    
    r.xml.should == "<methodResponse><params><param><value><int>3</int></value></param></params></methodResponse>"
  end

  it "should handle a bad request" do
    r = XmlRpc::API::Base.handle_request(TestController.new, '<methodCall>
      <methodName>crash</methodName>
      <params>
        <param><value>OHNOES!</value></param>
      </params>
    </methodCall>', {'crash' => :crash}) #"
    r.xml.should == "<methodResponse><fault><value><struct><member><name>faultString</name><value><string>Error: OHNOES!</string></value></member><member><name>faultCode</name><value><int>0</int></value></member></struct></value></fault></methodResponse>"
  end
    
  it "should handle a request with a method name mapping" do
    r = XmlRpc::API::Base.handle_request(TestController.new, '<methodCall>
      <methodName>examples.getStateName</methodName>
      <params>
        <param><value><int>41</int></value></param>
      </params>
    </methodCall>', {'examples.getStateName' => :get_state_name}) #"
    r.xml.should == "<methodResponse><params><param><value><string>South Dakota</string></value></param></params></methodResponse>"
  end


  it "should send a request and create a response" do
    options = {:url => 'http://betty.userland.com/RPC2', :method => 'examples.getStateName', :params => [41]}
    response = XmlRpc::API::Base.send_request(options)
    response.value.should == "South Dakota"
  end
end