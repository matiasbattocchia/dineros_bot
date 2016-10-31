# Dineros bot

https://web.telegram.org/#/im?p=@dineros_bot

Dineros accounts shared expenditures.
Invite it to your Telegram groups!
Even reckonings make long friends.

### Commands
* calculo - cuenta rápida de un gasto
* pago - registrar gasto compartido
* pago_desigual - gasto no tan compartido
* prestamo - transferencia entre dos
* balance - estado de las cuentas
* usuarios - gestión del grupo
* ayuda - consultas y sugerencias

### About
¿Gastos compartidos con amigos? Invita a Dineros a tus grupos de Telegram y deja que se encargue de las cuentas.

### Description
Dineros será de ayuda cada vez que compartas comidas, salidas y viajes con tus amigos. Es fantástico para el día a día de la convivencia y trabajo.

Despreocúpate de los gastos compartidos, Dineros se ocupará de llevar las cuentas.

Tiene dos modalidades de uso. En conversaciones grupales registra los gastos informados por todos. En conversaciones individuales es una calculadora que te permite repartir gastos con facilidad.


### TODO
Private chat:

1. Categories for complex quick calculations
2. General balance (all groups involved)

Group chat:

1. Accounting for projects

General:

1.  Better negative money formatting
2.  Balance aggregation to reduce DB stress
3.  True i18n (commands, money, etc.)
4.  Periodic remainders (rent, bills, etc.)
5.  Payment follow-ups
6.  Payment templates (same participants)
7.  Monthly balance auto-calculation
8.  'Next payer' recommendation
9.  Basic math operands
10. Contribution amount list in the same message (eggs 10, milk 20, bread 30)
11. Corrections during payment
12. Numeral separator regular expression
13. Use HTML instead of Markdown as it is more robust
14. Translate written numbers to numbers from zero to twenty
15. Some small talk ("I'm better than Splitwise" message when mentioned, <3 for appreciation, etc.)

### Bugs

* Interactive command timeout.
