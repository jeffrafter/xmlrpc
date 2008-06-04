require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/../../lib/xmlrpc'
require 'rexml/document'

describe "XmlRpc", "API", "Message" do

  it "should parse values" do
    parse_value('<param>value</param>').should == 'value'
  end  

  it "should parse boolean values" do
    parse_value('<param><boolean>true</boolean></param>').should === true
  end  

  it "should parse int values" do
    parse_value('<param><int>1</int></param>').should == 1
  end  

  it "should parse i4 values" do
    parse_value('<param><i4>1</i4></param>').should == 1
  end  

  it "should parse double values" do
    parse_value('<param><double>1.1</double></param>').should == 1.1
  end  

  it "should parse date values" do
    parse_value('<param>
                   <dateTime.iso8601>2001-01-01T13:01</dateTime.iso8601>
                 </param>').should == DateTime.new(2001, 01, 01, 13, 01) #"
  end  

  it "should parse base64 encoded values" do
    parse_value('<param><base64>eW91IGNhbid0IHJlYWQgdGhpcyE=</base64></param>').decoded_value.should == "you can't read this!"
  end  

  it "should parse array values" do
    parse_value('<param>
                   <array>
                     <data>
                       <value><i4>12</i4></value>
                       <value><string>Egypt</string></value>
                       <value><boolean>0</boolean></value>
                       <value><i4>-31</i4></value>
                     </data>
                   </array>
                 </param>').should == [12, 'Egypt', false, -31] #"
  end  

  it "should parse struct values" do
    parse_value('<param>
                   <struct>
                     <member>
                       <name>lowerBound</name>
                       <value><i4>18</i4></value>
                     </member>
                     <member>
                       <name>upperBound</name>
                       <value><i4>139</i4></value>
                     </member>
                   </struct>
                 </param>').should == {'lowerBound' => 18, 'upperBound' => 139} #"
  end  

  it "should parse nested array values" do
    parse_value('<param>
                   <array>
                     <data>
                       <value>
                         <array>
                           <data>
                             <value>Joe</value>
                           </data>
                         </array>
                       </value>
                     </data>
                   </array>
                 </param>').should == [['Joe']] #"
  end  

  it "should parse nested struct values" do
    parse_value('<param>
                   <struct>
                     <member>
                       <name>Joe</name>
                       <value>
                         <struct>
                           <member>
                             <name>Mode</name>
                             <value>Bike</value>
                           </member>
                         </struct>
                       </value>
                     </member>
                   </struct>
                 </param>').should == {'Joe' => {'Mode' => 'Bike'}} #"
  end  

  it "should build values" do
    build_value('OHNOES!').should == "<string>OHNOES!</string>"
  end  

  it "should build boolean values" do
    build_value(false).should == "<boolean>false</boolean>"
    build_value(true).should == "<boolean>true</boolean>"
  end  

  it "should build integer values" do
    build_value(1).should == "<int>1</int>"
  end  

  it "should build float values" do
    build_value(1.1).should == "<double>1.1</double>"
  end  

  it "should build date values" do    
    build_value(Date.parse("2004-09-13")).should == "<dateTime.iso8601>2004-09-13</dateTime.iso8601>"
  end  

  it "should build datetime values" do
    build_value(DateTime.parse("2004-09-13")).should == "<dateTime.iso8601>2004-09-13T00:00:00Z</dateTime.iso8601>"
    build_value(DateTime.parse("2004-09-13T02:38")).should == "<dateTime.iso8601>2004-09-13T02:38:00Z</dateTime.iso8601>"
  end  

  it "should build time values" do
    build_value(Time.gm(2004, 9, 13, 2, 38)).should == "<dateTime.iso8601>2004-09-13T02:38:00Z</dateTime.iso8601>"
  end  

  it "should build base 64 encoded values" do
    build_value(XmlRpc::API::Value.new(:base64, "you can't read this!")).should == "<base64>eW91IGNhbid0IHJlYWQgdGhpcyE=</base64>"
  end  

  it "should build array values" do
    build_value(['a', 1, true]).should == "<array><data><value><string>a</string></value><value><int>1</int></value><value><boolean>true</boolean></value></data></array>"
  end  

  it "should build hash values" do
    build_value({'a' => 1, 'b' => true}).should == "<struct><member><name>a</name><value><int>1</int></value></member><member><name>b</name><value><boolean>true</boolean></value></member></struct>"
  end  

  it "should build nested array values" do
    build_value(['a', [1, true]]).should == "<array><data><value><string>a</string></value><value><array><data><value><int>1</int></value><value><boolean>true</boolean></value></data></array></value></data></array>"
  end  

  it "should build nested hash values" do
    build_value({'a' => {'b' => 1}}).should == "<struct><member><name>a</name><value><struct><member><name>b</name><value><int>1</int></value></member></struct></value></member></struct>"
  end  

  def parse_value(xml)     
    XmlRpc::API::Message.parse_value(REXML::Document.new(xml).root)
  end
  
  def build_value(value)
    builder = Builder::XmlMarkup.new(:indent => 0)
    XmlRpc::API::Message.build_value(builder, value)
  end

end