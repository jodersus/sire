
Se detectó que las deploy keys (.deploy_key y .deploy_key.pub) estaban en el repositorio Git. Esto es un incidente de seguridad.

## Acciones tomadas

1. **Eliminados del repo local**: `git rm .deploy_key .deploy_key.pub`
2. **Commit de eliminación**: creado pero no push

## Estado actual

- La deploy key aún está en el **historial de git** (commits anteriores)
- El archivo .deploy_key fue eliminado del filesystem, impidiendo push
- Se creó una deploy key temporal para poder hacer push de la limpieza

## Próximos pasos requeridos

1. **Revocar la deploy key comprometida** en GitHub:
   - Ve a https://github.com/jodersus/sire/settings/keys
   - Elimina la deploy key con fingerprint: SHA256:IJ5NeTWmNySTw2FzUrSE1c/cOrJY479HpZb6NqqPB1IY

2. **Limpiar historial de git** (requiere force push):
   ```bash
   git filter-repo --path .deploy_key --path .deploy_key.pub --invert-paths
   git push origin main --force
   ```

3. **Eliminar .deploy_key del .gitignore** si estaba allí

## Lección aprendida

Las deploy keys nunca deben estar en el repo. El .gitignore debería haberlas excluido desde el inicio.
