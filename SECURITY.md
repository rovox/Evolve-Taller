# Guía de Seguridad - Evolve Deployment

## 🔐 Información Sensible Protegida

Este repositorio está configurado para **NO** incluir información sensible en Git. Los siguientes archivos están excluidos en `.gitignore`:

### Archivos protegidos:
- ✅ `stacks/*/. env` - Variables de entorno con credenciales
- ✅ `stacks/single-sequencer/passphrase` - Passphrase del secuenciador
- ✅ `volumes/` - Datos de blockchain y wallets de Celestia
- ✅ `*.backup` - Archivos de respaldo

### Archivos seguros para commit:
- ✅ `stacks/*/.env.example` - Plantillas sin datos reales
- ✅ `stacks/single-sequencer/passphrase.example` - Plantilla de passphrase
- ✅ `docker-compose.yml` - Configuración de servicios
- ✅ `Makefile` - Scripts de automatización

---

## 🚨 Prácticas de Seguridad Recomendadas

### 1. Namespaces de Celestia DA

Los namespaces (`DA_HEADER_NAMESPACE` y `DA_DATA_NAMESPACE`) identifican tu aplicación en Celestia:

- **¿Por qué protegerlos?** Si alguien conoce tus namespaces, podría leer los datos que publicas en Celestia DA.
- **Recomendación**: Genera namespaces únicos y no los compartas públicamente.
- **Generación**: Usa la [herramienta oficial de Celestia](https://docs.celestia.org/developers/namespace) o genera valores hexadecimales aleatorios de 29 bytes.

```bash
# Ejemplo de formato (NO uses este valor real):
DA_HEADER_NAMESPACE="0x00000000000000000000000000000000000000000123456789abcdef012345"
```

### 2. Passphrase del Secuenciador

El archivo `passphrase` desbloquea la cuenta que firma bloques:

- **¿Por qué protegerlo?** Quien tenga este passphrase puede firmar bloques en tu nombre.
- **Recomendación**: Genera uno nuevo con `openssl rand -base64 32` y guárdalo de forma segura.
- **Nunca** lo incluyas en el repositorio Git.

### 3. Claves Privadas del Faucet

La clave privada en `stacks/eth-faucet/.env` controla la cuenta que distribuye fondos:

- **⚠️ ADVERTENCIA**: Usa solo cuentas de prueba. Nunca uses claves con fondos reales.
- **Recomendación**: Genera una cuenta nueva específicamente para el faucet.
- **Limitación**: Configura el faucet para distribuir cantidades pequeñas.

### 4. Credenciales del Explorador

El explorador Blockscout usa PostgreSQL y Phoenix Framework:

- `EXPLORER_POSTGRES_PASSWORD`: Contraseña de base de datos
- `SECRET_KEY_BASE`: Clave para sesiones y cookies de Phoenix

**Generación segura**:
```bash
# PostgreSQL password (16 bytes hex)
openssl rand -hex 16

# Phoenix secret (64 bytes base64)
openssl rand -base64 64
```

### 5. Volúmenes de Docker

Los volúmenes contienen:
- Wallet de Celestia (generada automáticamente por `cel-key`)
- Datos de blockchain
- Estado de bases de datos

**⚠️ IMPORTANTE**: 
- `make stop-with-volumes` o `make clean` **ELIMINARÁN** estos datos
- Haz backup de las claves antes de limpiar volúmenes
- Para exportar la clave de Celestia:

```bash
docker exec -it celestia-node cel-key export <key-name> --node.type=light
```

---

## 📋 Checklist de Seguridad

Antes de usar este stack en un entorno semi-público, verifica:

- [ ] Todos los archivos `.env` contienen valores únicos (no los de ejemplo)
- [ ] El passphrase fue generado con `openssl rand -base64 32`
- [ ] Los namespaces de DA son únicos y privados
- [ ] La clave privada del faucet es nueva y sin fondos reales
- [ ] Las contraseñas de PostgreSQL son seguras
- [ ] Has hecho backup de la wallet de Celestia (si es importante)
- [ ] El `.gitignore` está funcionando (`git status` no muestra archivos `.env`)

---

## 🔍 Verificar qué se subiría a Git

Antes de hacer commit, verifica que no haya archivos sensibles:

```bash
# Ver archivos que se subirían
git status

# Ver diferencias
git diff

# Verificar que .gitignore funciona
git check-ignore -v stacks/da-celestia/.env
# Debería mostrar: .gitignore:5:stacks/da-celestia/.env
```

Si ves archivos `.env` o `passphrase` en `git status`, **NO** hagas commit. Revisa tu `.gitignore`.

---

## 🆘 ¿Qué hacer si subiste datos sensibles por error?

Si accidentalmente subiste información sensible:

1. **Inmediatamente** cambia todas las credenciales expuestas
2. **NO** uses `git revert` o `git reset` simple (los datos quedan en el historial)
3. Usa herramientas especializadas como:
   - `git-filter-repo` (recomendado)
   - `BFG Repo-Cleaner`
4. Contacta a GitHub para purgar cachés si es un repositorio público

**Prevención**: Revisa siempre con `git diff --staged` antes de commitear.

---

## 📚 Referencias

- [Celestia Namespace Documentation](https://docs.celestia.org/developers/namespace)
- [Celestia Security Best Practices](https://docs.celestia.org/nodes/security)
- [Git Secrets Management](https://git-scm.com/book/en/v2/Git-Tools-Credential-Storage)
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)

---

## 🤝 Contribuir de Forma Segura

Si vas a contribuir a este repositorio:

1. **Nunca** incluyas tus archivos `.env` reales en PRs
2. Solo modifica archivos `.env.example` si es necesario
3. Documenta nuevas variables de entorno en los archivos `.example`
4. Revisa el diff antes de crear el PR: `git diff main..tu-rama`

---

**Última actualización**: Noviembre 2025
