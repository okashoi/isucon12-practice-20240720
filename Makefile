.PHONY: *

gogo: stop-services build sync-app truncate-logs start-services

stop-services:
	sudo systemctl stop nginx
	sudo systemctl stop isuports.service
	ssh isucon-s2 "sudo systemctl stop isuports.service"
	ssh isucon-s3 "sudo systemctl stop isuports.service"
	ssh isucon-s3 "sudo systemctl stop mysql"

sync-app:
	scp -r go isucon-s2:~/webapp/
	scp -r go isucon-s3:~/webapp/

build:
	cd go && make

truncate-logs:
	sudo journalctl --vacuum-size=1K
	sudo truncate --size 0 /var/log/nginx/access.log
	sudo truncate --size 0 /var/log/nginx/error.log
	ssh isucon-s3 "sudo truncate --size 0 /var/log/mysql/mysql-slow.log && sudo chmod 666 /var/log/mysql/mysql-slow.log"
	ssh isucon-s3 "sudo truncate --size 0 /var/log/mysql/error.log"

start-services:
	ssh isucon-s3 "sudo systemctl start mysql"
	sudo systemctl start isuports.service
	ssh isucon-s2 sudo systemctl start isuports.service
	ssh isucon-s3 sudo systemctl start isuports.service
	sudo systemctl start nginx

kataribe: timestamp=$(shell TZ=Asia/Tokyo date "+%Y%m%d-%H%M%S")
kataribe:
	mkdir -p ~/kataribe-logs
	sudo cp /var/log/nginx/access.log /tmp/last-access.log && sudo chmod 666 /tmp/last-access.log
	cat /tmp/last-access.log | kataribe -conf kataribe.toml > ~/kataribe-logs/$$timestamp.log
	cat ~/kataribe-logs/$$timestamp.log | grep --after-context 20 "Top 20 Sort By Total"

pprof: TIME=60
pprof: PROF_FILE=~/pprof.samples.$(shell TZ=Asia/Tokyo date +"%H%M").$(shell git rev-parse HEAD | cut -c 1-8).pb.gz
pprof:
	curl -sSf "http://localhost:6060/debug/fgprof?seconds=$(TIME)" > $(PROF_FILE)
	go tool pprof $(PROF_FILE)
