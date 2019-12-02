
echo "cloning geo-docker library and starting geomesa..."
su $SSUSER -c 'cd ~ && git clone https://github.com/geodocker/geodocker-geomesa.git && cd ~/geodocker-geomesa/geodocker-accumulo-geomesa && docker-compose pull;'
echo "getting opensky data from Aug 18"
yum install -y wget
wget https://bootstrap.pypa.io/get-pip.py
python get-pip.py
pip install requests
su $SSUSER -c 'cd ~ && curl -o googledoc.py -L https://raw.githubusercontent.com/brownnrl/linux-deployment-scripts/master/GeoDocker/googledoc.py && chmod +x googledoc.py && ./googledoc.py 19GHBWBresVR6ZTfgRBQNzR_iIW-vXU3e opensky.csv.gz && gunzip opensky.csv.gz'
