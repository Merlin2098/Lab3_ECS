# 01 — Crear el Remote Backend S3

Crea el bucket S3 que almacenará el Terraform state de la infraestructura principal.
Ejecutar **una sola vez** antes de inicializar `infra/`.

---

## Windows (PowerShell)

### Paso 0 — Cargar credenciales AWS

```powershell
# Carga las variables de entorno desde infra/env/.env.credentials
# Ignora líneas vacías y comentarios (#)
Get-Content infra\env\.env.credentials | ForEach-Object {
  if ($_ -match "^\s*#" -or $_ -match "^\s*$") { return }

  $name, $value = $_ -split "=", 2
  [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim(), "Process")
}

# Verificar que las credenciales están activas
aws sts get-caller-identity
```

### Paso 1 — Crear el bucket S3

```powershell
# Ir a backend-bootstrap/ guardando la ubicación actual
Push-Location backend-bootstrap

# Inicializar Terraform (estado local)
terraform init

# Revisar el plan
terraform plan

# Crear el bucket S3
terraform apply

# Capturar el nombre del bucket en una variable
$BUCKET_NAME = terraform output -raw bucket_name
Write-Host "Bucket creado: $BUCKET_NAME"

# Reemplazar el placeholder en infra/backend.tf
(Get-Content ..\infra\backend.tf) `
  -replace 'REPLACE_WITH_BUCKET_NAME', $BUCKET_NAME |
  Set-Content ..\infra\backend.tf

Write-Host "infra/backend.tf actualizado con: $BUCKET_NAME"

# Volver al directorio anterior
Pop-Location
```

---

## Linux / macOS (bash)

### Paso 0 — Cargar credenciales AWS

```bash
# Carga las variables de entorno desde infra/env/.env.credentials
# Ignora líneas vacías y comentarios (#)
set -o allexport
source <(grep -v '^\s*#' infra/env/.env.credentials | grep -v '^\s*$')
set +o allexport

# Verificar que las credenciales están activas
aws sts get-caller-identity
```

### Paso 1 — Crear el bucket S3

```bash
# Ir a backend-bootstrap/ guardando la ubicación actual
pushd backend-bootstrap

# Inicializar Terraform (estado local)
terraform init

# Revisar el plan
terraform plan

# Crear el bucket S3
terraform apply

# Capturar el nombre del bucket en una variable
BUCKET_NAME=$(terraform output -raw bucket_name)
echo "Bucket creado: $BUCKET_NAME"

# Reemplazar el placeholder en infra/backend.tf
sed -i "s/REPLACE_WITH_BUCKET_NAME/$BUCKET_NAME/" ../infra/backend.tf

echo "infra/backend.tf actualizado con: $BUCKET_NAME"

# Volver al directorio anterior
popd
```

---

## Resultado esperado

- Bucket S3 creado: `ecs-terraform-lab-tfstate-<account_id>`
- Versioning habilitado, SSE-S3 activo, block public access en todos los bloques.
- `infra/backend.tf` con el nombre real del bucket (sin placeholder).

---

## Cleanup del backend

Solo ejecutar **después** de destruir la infraestructura principal (`infra/`):

```powershell
# Recargar credenciales si la sesión cambió
Get-Content infra\env\.env.credentials | ForEach-Object {
  if ($_ -match "^\s*#" -or $_ -match "^\s*$") { return }
  $name, $value = $_ -split "=", 2
  [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim(), "Process")
}

Push-Location backend-bootstrap
terraform destroy
Pop-Location
```

```bash
set -o allexport
source <(grep -v '^\s*#' infra/env/.env.credentials | grep -v '^\s*$')
set +o allexport

pushd backend-bootstrap
terraform destroy
popd
```
