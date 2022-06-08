+++
title="[PL] Własny Amazon S3 na Mikrusie?"
date=2022-01-08
+++
*This article is written in Polish, for the [Mikrus](https://mikr.us) project.*
# Czym jest MinIO?
***MinIO*** to napisany w Go otwartoźródłowy serwer *object storage* kompatybilny z **Amazon S3**. Posiada bardzo duże możliwości konfiguracji, a jego instalacja jest dość prosta.

W tym poście, chciałbym opisać jego instalację na [Mikrusie](https://mikr.us)

# Instalacja
Instalację przeprowadzimy na następującej konfiguracji:
* *Mikrus*, najlepiej 2.0 lub 3.0
* *Alpine Linux* - bardzo lekka, szybka i nieskomplikowana w budowie dystrybucja Linuxa
* *Mikrusowy Storage* - *Mikrusy* nie mają zbyt dużo "własnego" dysku, a zdalny storage odpada ze względu na charakter usługi jaką jest S3
* *Własna domena* - potrzebna do SSL, a mikrusowa subdomena się nie nada ze względu na ograniczenia Cloudflare co do rozmiaru zapytania HTTP

## Porty użyte w poradniku
Ta lista powinna pomóc ci uzupełnić pliki konfiguracyjne odpowiednimi portami
* **9000** - domyślny, *wewnętrzny* port MinIO
* **9001** - domyślny, *wewnętrzny* port MinIO Console
* **12345** - *zewnętrzny* port z [panelu Mikrusa](https://mikr.us/panel?a=ports)

## Rekordy DNS
Stwórz dwa rekordy:

<table><thead><tr>
    <td>Typ</td><td>Nazwa</td><td>Adres</td>
</thead><tbody></tr><tr>
    <td>CNAME</td><td>minio</td><td>srvXX.mikr.us</td>
</tr><tr>
    <td>CNAME</td><td>console.minio</td><td>srvXX.mikr.us</td>
</tr></tbody></table>

Zamień *srvXX* na adres serwera twojego Mikrusa (np. srv08.mikr.us).
Będziesz musiał ogarnąć też certyfikat SSL dla tych dwóch rekordów i umieścić go w */etc/ssl/minio/* (patrz. *Konfiguracja reverse proxy*);

---
MinIO jest dostępny jako pakiet Alpine, lecz użyjemy binarki, gdyż po pierwsze, jest to najnowsza wersja (a MinIO jest *bardzo* często aktualizowany), a po drugie, taki sposób instalacji zaleca producent.

W tym celu, wykonaj następujące polecenia **jako root**:
```bash
apk add curl
curl https://dl.min.io/server/minio/release/linux-amd64/minio -o /usr/bin/minio
chmod +x /usr/bin/minio
addgroup -S minio
adduser -S -D -h /var/lib/minio -s /sbin/nologin -G minio -g minio minio
```

MinIO nie posiada własnego skryptu OpenRC, więc napisałem swój. Umieść go w */etc/init.d/minio*:
```bash
#!/sbin/openrc-run
name='MinIO Server'
command=/usr/bin/minio
command_args="server --address $MINIO_ADDR --console-address $MINIO_CONSOLE_ADDR $MINIO_VOLUME"
command_user="minio:minio"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/${RC_SVCNAME}.log"

depend() {
    need net
    use logger
}

start_pre() {
    checkpath --file --mode 0600 --owner root:root "/etc/conf.d/${RC_SVCNAME}"
    checkpath --file --mode 0644 --owner minio:minio "/var/log/${RC_SVCNAME}.log"
    checkpath --directory --mode 0700 --owner minio:minio "$MINIO_VOLUME"
}
```
Nie zapomnij ustawić uprawnień wykonywania:
```bash
chmod +x /etc/init.d/minio
```

## Konfiguracja serwera MinIO
**Ważne:** Upewnij się, że twój Mikrusowy storage jest zamontowany jako */storage*.

Stwórz plik */etc/conf.d/minio* (jako root) i umieść w nim następującą zawartość:
```bash
# ścieżka do całego "środowiska" S3
MINIO_VOLUME="/storage/S3"

# nazwa użytkownika administratora
export MINIO_ROOT_USER=lemonsh
# hasło administratora
export MINIO_ROOT_PASSWORD=WysmieniteHaslo

# porty TCP, zmień jeśli potrzebujesz
MINIO_ADDR=:9000 # główny port
MINIO_CONSOLE_ADDR=:9001 # MinIO Console

# ustaw tutaj adres za pomocą którego można dostać się do MinIO Console z zewnątrz
export MINIO_BROWSER_REDIRECT_URL=https://console.minio.example.com:12345

# nie powinieneś/aś musieć tego zmieniać
export MINIO_SERVER_URL=http://127.0.0.1$MINIO_ADDR
```
Zmień odpowiednie wartości zgodnie z ich opisem w komentarzach.

## Konfiguracja reverse proxy
MinIO posiada swój własny webowy panel kontrolny zwany MinIO Console, który wystawiony jest przez port *inny* od głównego.
Zatem, MinIO w zasadzie wystawia dwie osobne usługi HTTP na osobnych portach. Aby wystawić je do internetu, możemy użyć *nginx*.

Nie będę tutaj opisywał całej konfiguracji samego nginxa, a jedynie samą część configu która będzie ci potrzebna:
```conf
server {
    # zamień 12345 na port zewnętrzny (patrz "Porty użyte w poradniku")
    listen 12345 ssl; 
    # zamień example.com na swoją domenę
    server_name minio.example.com;
    
    # ustaw tutaj ścieżki do certyfikatu SSL
    ssl_certificate /etc/ssl/minio/public.crt;
    ssl_certificate_key /etc/ssl/minio/private.key;

    # opcjonalnie, tu możesz ustawić maksymalny rozmiar pliku, np. 100m
    client_max_body_size 0;

    ignore_invalid_headers off;
    proxy_buffering off;

    location / {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;

        proxy_connect_timeout 300;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        chunked_transfer_encoding off;

        proxy_pass http://127.0.0.1:9000; # zmień 9000 na port *główny* (jeśli się różni)
    }
}

server {
    # zamień 12345 na port zewnętrzny (patrz "Porty użyte w poradniku")
    listen 12345 ssl; 
    # zamień example.com na swoją domenę
    server_name console.minio.example.com;
    
    # ustaw tutaj ścieżki do certyfikatu SSL
    ssl_certificate /etc/ssl/minio/public.crt;
    ssl_certificate_key /etc/ssl/minio/private.key;

    # opcjonalnie, tu możesz ustawić maksymalny rozmiar pliku, np. 100m
    client_max_body_size 0;

    ignore_invalid_headers off;
    proxy_buffering off;

    location / {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;

        proxy_connect_timeout 300;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        chunked_transfer_encoding off;

        proxy_pass http://127.0.0.1:9001; # zmień 9001 na port *konsoli* (jeśli się różni)
    }
}
```
Zmień odpowiednie wartości zgodnie z ich opisem w komentarzach.

Nie zapomnij zrestartować nginxa:
```bash
service nginx restart
```

# E, działa to?
Upewnij się, że konfiguracja jest prawidłowa i uruchom MinIO:
```bash
service minio start
```
Jeśli nie pojawią się żadne błędy, wejdź na adres *https://console.minio.twojadomena.pl:12345*.
Jeśli instalacja przebiegła bezbłędnie, powinieneś zobaczyć interfejs logowania do MinIO Console.
Użyj wcześniej ustalonych poświadczeń (*Konfiguracja serwera MinIO*).

Działa?

* Jeśli tak, gratulacje!
* Jeśli nie, jak coś logi są w */var/log/minio.log*, powodzenia!