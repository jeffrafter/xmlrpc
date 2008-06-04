require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/../../lib/xmlrpc'

describe "XmlRpc", "API", "Response" do
  before :all do
    @response = XmlRpc::API::Response.new(:xml =>
'<methodResponse>
  <params>
    <param>
      <value>
        <string>South Dakota</string>
      </value>
    </param>
  </params>
</methodResponse>
') #"
     
    @fault_response = XmlRpc::API::Response.new(:xml =>
'<methodResponse>
  <fault>
    <value>
      <struct>
        <member>
          <name>faultString</name>
          <value>
            <string>Too many parameters.</string>
          </value>
        </member>
        <member>
          <name>faultCode</name>
          <value>
            <int>4</int>
          </value>
        </member>
      </struct>
    </value>
  </fault>
</methodResponse>
') #"
  end
  
  it "should be valid when it does not have a fault" do
    @response.is_valid?.should === true
  end
  
  it "should be invalid when it does have a fault" do
    @fault_response.is_valid?.should === false
  end
  
  it "should parse the fault code" do
    @fault_response.fault_code.should == 4
  end
  
  it "should parse the fault string" do
    @fault_response.fault_string.should == "Too many parameters."
  end
  
  it "should format the error message" do
    @fault_response.error.should == "Too many parameters. (4)"
  end
  
  it "should parse the response value" do
    @response.value.should == "South Dakota"
  end
  
  it "should build a response with a value" do
    XmlRpc::API::Response.new(:value => "South Dakota", :indent => 2).xml.should == @response.xml
  end

  it "should build a response with a fault" do
    fault = XmlRpc::API::Fault.new("Too many parameters.", 4)
    XmlRpc::API::Response.new(:fault => fault, :indent => 2).xml.should == @fault_response.xml
  end
  
end