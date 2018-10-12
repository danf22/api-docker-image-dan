#!/usr/bin/env sh
currentBranch=$(git branch | head -n1 | cut -d' ' -f 2);

composer install --prefer-dist --no-progress --no-suggest --no-interaction \
  && setfacl -dR -m u:www-data:rwx,g:www-data:rwx var/ vendor/ public/ config/
	chmod -R 666 composer.json composer.lock
	chmod -R u+s,g+s ./*
  	chmod -R 777 var/ public/ vendor/
	chown -R www-data:www-data var/ vendor/ public/ \
	&& chown -R www-data:www-data .git/ config/
	chown www-data:www-data .git/index
	if [ "$currentBranch" = 'master' ]; then
		git checkout develop;
	fi
		bin/console doctrine:migrations:migrate --no-interaction \
		&& bin/console fos:elastica:populate
	
exec docker-php-entrypoint "$@"
