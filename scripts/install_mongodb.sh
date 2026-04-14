#!/bin/bash
set -e

# Amazon Linux 2023 - Instalar MongoDB 7.0

# 1. Agregar repositorio oficial de MongoDB
cat <<EOF > /etc/yum.repos.d/mongodb-org-7.0.repo
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF

# 2. Instalar MongoDB
dnf install -y mongodb-org

# 3. Bind en 0.0.0.0 para aceptar conexiones externas
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

# 4. Arrancar MongoDB SIN autenticación primero (para crear el usuario admin)
systemctl daemon-reload
systemctl enable mongod
systemctl start mongod

# 5. Esperar a que MongoDB esté listo
echo "Esperando a que MongoDB arranque..."
until mongosh --quiet --eval "db.adminCommand('ping').ok" | grep -q 1; do
  echo "  ...todavía no está listo"
  sleep 3
done
echo "MongoDB listo."

# 6. Crear usuario administrador
mongosh admin --eval "
  db.createUser({
    user: 'admin',
    pwd: 'password123',
    roles: [
      { role: 'userAdminAnyDatabase', db: 'admin' },
      { role: 'readWriteAnyDatabase', db: 'admin' }
    ]
  })
"

# 7. Activar autenticación
cat <<EOF >> /etc/mongod.conf
security:
  authorization: enabled
EOF

# 8. Reiniciar para aplicar autenticación
systemctl restart mongod

# 9. Esperar a que vuelva a estar listo
echo "Esperando a que MongoDB reinicie con autenticación..."
sleep 5
until mongosh "mongodb://admin:password123@localhost:27017/admin?authSource=admin" \
  --quiet --eval "db.adminCommand('ping').ok" | grep -q 1; do
  echo "  ...esperando"
  sleep 3
done

echo "MongoDB instalado y securizado correctamente a las $(date)" >> /var/log/mongodb_setup.log
