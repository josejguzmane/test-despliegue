## Que cambia

<!-- Una o dos frases. Que fase toca y por que. -->

## Fases afectadas

- [ ] 00-foundation
- [ ] 10-network-hub
- [ ] 20-network-spoke
- [ ] 30-data
- [ ] 40-aks
- [ ] 50-edge
- [ ] 60-observability
- [ ] 70-security

## Revision del plan

- [ ] Lei el comentario con el `terraform plan` de cada fase afectada
- [ ] Ningun recurso aparece como **destroy** o **replace** sin que sea intencional
- [ ] Si enciendo un feature flag de costo, lo indico abajo con el costo mensual estimado

## Impacto en costo

<!-- "ninguno" si solo cambian recursos sin costo fijo. -->

## Impacto en seguridad y red

- [ ] No se crean IPs publicas fuera del hub
- [ ] No se abre acceso publico de red en servicios de datos
- [ ] No se introducen secretos en el codigo ni en variables
