# Dineros bot

https://web.telegram.org/#/im?p=@dineros_bot

Dineros accounts shared expenditures.
Invite him to your Telegram groups!
Even reckonings make long friends.

### Commands
* cancelar - un comando interactivo
* calculo - cuenta rápida de un gasto
* pago - registrar gasto compartido
* pago_desigual - gasto no tan compartido
* prestamo - transferencia entre dos
* balance - estado de las cuentas
* usuarios - gestión del grupo
* ayuda - consultas y sugerencias

### About
Dineros lleva el registro de gastos comunes. Invítalo a tu grupo de amigos.
Las cuentas claras conservan la amistad.

### Description


### TODO
Private chat:

1. Categories for complex quick calculations
2. General balance (all groups involved)

Group chat:

1. Accounting for projects

General:

1. /explain command
2. Balance aggregation to reduce DB stress
3. True i18n (commands, money, etc.)
4. Periodic remainders (rent, bills, etc.)
5. Payment follow-ups
6. Payment templates (same participants)
7. Monthly balance auto-calculation
8. 'Next payer' recommendation
9. Basic math operands
10. Contribution amount list in the same message (eggs 10, milk 20, bread 30)
12. Corrections during payment
13. Numeral separator regular expression
14. Always-present cancel button during interactive commands
15. Use HTML instead of Markdown as it is more robust

### Bugs

* Machine instances timeout
* Expert payment advice does not reflect the one-payer-all-participants
  feature, and the expert payment does not inform about the participants
