require 'mime/types'

class MultipartParams #:nodoc:
  attr_accessor :content_type, :body
  
  def initialize(param_hash={})
    @boundary_token = generate_boundary_token    
    self.content_type = "multipart/form-data; boundary=#{@boundary_token}"        
    self.body = pack_params(param_hash)    
  end

  protected
  
  def generate_boundary_token
    [Array.new(8) {rand(256)}].join
  end
  
  def pack_params(hash)
    marker = "--#{@boundary_token}"
    # Partition the hash, then return 2 hashes from the arrays returned.
    files_params, text_params = hash.partition { |k,v| v.is_a?(File) or v.is_a?(Tempfile) }.map do |a|
                                      # Converts array like [['foo', 'bar']] => {'foo' => 'bar'}
                                      a.inject({}) { |h, x| h[x[0]] = x[1]; h }
                                    end
    
    pack_hash(text_params, marker+"\r\n") + pack_hash(files_params, marker+"\r\n") + marker + "--"
  end
  
  def pack_hash(hash, marker)
    hash.map do |name, value|
      marker + case value
      when String, Fixnum
        text_to_multipart(name, value)
      when File, Tempfile
        file_to_multipart(name, value)
      else
        raise "Unexpected #{value.class}: #{value.inspect}"
      end
    end.join('')
  end
  
  def file_to_multipart(key,file)
    filename = File.basename(file.path)
    mime_types = MIME::Types.of(filename)
    mime_type = mime_types.empty? ? "application/octet-stream" : mime_types.first.content_type
    part = %Q[Content-Disposition: form-data; name="#{key}"; filename="#{filename}"\r\n]
    part += "Content-Transfer-Encoding: binary\r\n"
    part += "Content-Type: #{mime_type}\r\n\r\n#{file.read}\r\n"
  end

  def text_to_multipart(key,value)
    "Content-Disposition: form-data; name=\"#{key}\"\r\n\r\n#{value.to_s}\r\n"
  end
end
