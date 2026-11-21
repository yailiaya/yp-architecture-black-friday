# pymongo-api

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Заполняем mongodb данными

```shell
./scripts/mongo-init.sh
```

## Как проверить

### Если вы запускаете проект на локальной машине

Откройте в браузере http://localhost:8080

Список доступных эндпоинтов, swagger http://localhost:8080/docs

### Если вы запускаете проект на предоставленной виртуальной машине

Узнать белый ip виртуальной машины

```shell
curl --silent http://ifconfig.me
```

Откройте в браузере http://<ip виртуальной машины>:8080

## Доступные эндпоинты

Список доступных эндпоинтов, swagger http://<ip виртуальной машины>:8080/docs

## Диаграмма для варианта конфигурации приложения с кэшированием с Redis кластером и MongoDB шардами с репликацией

[Диаграмма для варианта с двумя шардами с репликацией и Redis кластером для кэша.](https://github.com/yailiaya/yp-architecture-black-friday/blob/mobilemir/Diagrams/schema_3_shards_replicas_cache.drawio)