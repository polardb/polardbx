set -eux

echo "Make sure you have already run make successfully"

build_path=$1

rm -rf tmp && mkdir -p tmp
cp -f entrypoint.sh tmp/
cp -f watchdog.sh tmp/
cp -f Dockerfile tmp/
old_pwd=$(pwd)
cd "$build_path"
tar -zcf run.tar.gz run
mv run.tar.gz "$old_pwd"/tmp/run.tar.gz
cd "$old_pwd"/tmp
sudo docker build -t all-in-one --network host . -f Dockerfile --build-arg BUILD_PATH="$build_path"
cd "$old_pwd" && rm -rf tmp
