require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/../../lib/xmlrpc'

describe "XmlRpc", "API", "Request" do
  it "should return the method name" do
    request.method.should == 'examples.getStateName'
  end  
  
  it "should return the parameters in an array" do
    request.params.should == [41]
  end  

  it "should generate the XML" do
    request.xml.should == 
'<methodCall>
  <methodName>examples.getStateName</methodName>
  <params>
    <param>
      <value>
        <int>41</int>
      </value>
    </param>
  </params>
</methodCall>
' #"          
  end

  def request
    XmlRpc::API::Request.new(:method => 'examples.getStateName', :params => [41], :indent => 2)
  end
  
end