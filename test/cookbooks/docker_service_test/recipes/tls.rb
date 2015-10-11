caroot = '/tmp/kitchen/tls'

directory "#{caroot}" do
  action :create
end

# Self signed CA
bash 'generating CA private and public key' do
  cmd = 'openssl req'
  cmd += ' -x509'
  cmd += ' -nodes'
  cmd += ' -days 365'
  cmd += ' -sha256'
  cmd += " -subj '/CN=kitchen2docker/'"
  cmd += ' -newkey rsa:4096'
  cmd += " -keyout #{caroot}/ca-key.pem"
  cmd += " -out #{caroot}/ca.pem"
  cmd += ' 2>&1>/dev/null'
  code cmd
  not_if "/usr/bin/test -f #{caroot}/ca-key.pem"
  not_if "/usr/bin/test -f #{caroot}/ca.pem"
  action :run
end

# server certs
bash 'creating private key for docker server' do
  code "openssl genrsa -out #{caroot}/server-key.pem 4096"
  not_if "/usr/bin/test -f #{caroot}/server-key.pem"
  action :run
end

bash 'generating certificate request for server' do
  cmd = 'openssl req'
  cmd += ' -new'
  cmd += ' -sha256'
  cmd += " -subj '/CN=#{node['hostname']}/'"
  cmd += " -key #{caroot}/server-key.pem"
  cmd += " -out #{caroot}/server.csr"
  code cmd
  only_if "/usr/bin/test -f #{caroot}/server-key.pem"
  not_if "/usr/bin/test -f #{caroot}/server.csr"
  action :run
end

file "#{caroot}/server-extfile.cnf" do
  content "subjectAltName = IP:#{node['ipaddress']},IP:127.0.0.1\n"
  action :create
end

bash 'signing request for server' do
  cmd = 'openssl x509'
  cmd += ' -req'
  cmd += ' -days 365'
  cmd += ' -sha256'
  cmd += " -CA #{caroot}/ca.pem"
  cmd += " -CAkey #{caroot}/ca-key.pem"
  cmd += ' -CAcreateserial'
  cmd += " -in #{caroot}/server.csr"
  cmd += " -out #{caroot}/server.pem"
  cmd += " -extfile #{caroot}/server-extfile.cnf"
  not_if "/usr/bin/test -f #{caroot}/server.pem"
  code cmd
  action :run
end

# client certs
bash 'creating private key for docker client' do
  code "openssl genrsa -out #{caroot}/key.pem 4096"
  not_if "/usr/bin/test -f #{caroot}/key.pem"
  action :run
end

bash 'generating certificate request for client' do
  cmd = 'openssl req'
  cmd += ' -new'
  cmd += " -subj '/CN=client/'"
  cmd += " -key #{caroot}/key.pem"
  cmd += " -out #{caroot}/client.csr"
  code cmd
  only_if "/usr/bin/test -f #{caroot}/key.pem"
  not_if "/usr/bin/test -f #{caroot}/client.csr"
  action :run
end

file "#{caroot}/client-extfile.cnf" do
  content "extendedKeyUsage = clientAuth\n"
  action :create
end

bash 'signing request for client' do
  cmd = 'openssl x509'
  cmd += ' -req'
  cmd += ' -days 365'
  cmd += ' -sha256'
  cmd += " -CA #{caroot}/ca.pem"
  cmd += " -CAkey #{caroot}/ca-key.pem"
  cmd += ' -CAcreateserial'
  cmd += " -in #{caroot}/client.csr"
  cmd += " -out #{caroot}/cert.pem"
  cmd += " -extfile #{caroot}/client-extfile.cnf"
  code cmd
  not_if "/usr/bin/test -f #{caroot}/cert.pem"
  action :run
end

# start docker service listening on TCP port
service_def = proc do
  host 'tcp://127.0.0.1:2376'
  tls_verify true
  tls_ca_cert "#{caroot}/ca.pem"
  tls_server_cert "#{caroot}/server.pem"
  tls_server_key "#{caroot}/server-key.pem"
  tls_client_cert "#{caroot}/cert.pem"
  tls_client_key "#{caroot}/key.pem"
  action [:create, :start]
end

if node['docker']['service_manager'] == 'execute'
  docker_service_execute('default', &service_def)
else
  docker_service('default', &service_def)
end
