# Brute force login (tentatives échouées)
for i in $(seq 1 20); do
  curl -s -X POST http://localhost:8000/api/auth/login/ \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"wrong'$i'"}' &
done
wait

# SQL injection attempts
curl -s "http://localhost:8000/api/auth/login/" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin'\'' OR 1=1--","password":"test"}'

curl -s "http://localhost:8000/api/auth/login/" \
  -H "Content-Type: application/json" \
  -d '{"username":"'; DROP TABLE users;--","password":"x"}'

# XSS attempts
curl -s "http://localhost:8000/api/auth/login/" \
  -H "Content-Type: application/json" \
  -d '{"username":"<script>alert(1)</script>","password":"test"}'

# Path traversal
curl -s "http://localhost:8000/api/../../etc/passwd"
curl -s "http://localhost:8000/api/..%2F..%2Fetc%2Fpasswd"

# Scan de ports (accès à des endpoints inexistants)
for path in admin wp-admin .env config.php phpmyadmin; do
  curl -s "http://localhost:8000/$path"
done

# Requêtes non authentifiées massives
for i in $(seq 1 30); do
  curl -s http://localhost:8000/api/accounts/ &
done
wait
