
FROM ghcr.io/cirruslabs/flutter:3.19.0 AS build
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release --dart-define=BASE_URL=http://104.248.61.147:8000

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80