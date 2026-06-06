# 01 — Crear el Remote Backend S3

Crea el bucket S3 que almacenará el Terraform state de la infraestructura principal.
Ejecutar **una sola vez** antes de inicializar `infra/`.

---

## Windows (PowerShell)

```powershell
# 1. Ir a backend-bootstrap/ guardando la ubicación actual
Push-Location backend-bootstrap

# 2. Inicializar Terraform (estado local)
terraform init

# 3. Revisar el plan
terraform plan

# 4. Crear el bucket S3
terraform apply

# 5. Capturar el nombre del bucket en una variable
$BUCKET_NAME = terraform output -raw bucket_name
Write-Host "Bucket creado: $BUCKET_NAME"

# 6. Reemplazar el placeholder en infra/backend.tf
(Get-Content ..\infra\backend.tf) `
  -replace 'REPLACE_WITH_BUCKET_NAME', $BUCKET_NAME |
  Set-Content ..\infra\backend.tf

Write-Host "infra/backend.tf actualizado con: $BUCKET_NAME"

# 7. Volver al directorio anterior
Pop-Location
```

---

## Linux / macOS (bash)

```bash
# 1. Ir a backend-bootstrap/ guardando la ubicación actual
pushd backend-bootstrap

# 2. Inicializar Terraform (estado local)
terraform init

# 3. Revisar el plan
terraform plan

# 4. Crear el bucket S3
terraform apply

# 5. Capturar el nombre del bucket en una variable
BUCKET_NAME=$(terraform output -raw bucket_name)
echo "Bucket creado: $BUCKET_NAME"

# 6. Reemplazar el placeholder en infra/backend.tf
sed -i "s/REPLACE_WITH_BUCKET_NAME/$BUCKET_NAME/" ../infra/backend.tf

echo "infra/backend.tf actualizado con: $BUCKET_NAME"

# 7. Volver al directorio anterior
popd
```

---

## Resultado esperado

- Bucket S3 creado: `ecs-terraform-lab-tfstate-<account_id>`
- Versioning habilitado, SSE-S3 activo, block public access en todos los bloques.
- `infra/backend.tf` con el nombre real del bucket (sin placeholder).

## Cleanup del backend

Solo ejecutar **después** de destruir la infraestructura principal (`infra/`):

```powershell
Push-Location backend-bootstrap
terraform destroy
Pop-Location
```

```bash
pushd backend-bootstrap
terraform destroy
popd
```
