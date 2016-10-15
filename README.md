# Dineros bot

https://web.telegram.org/#/im?p=@dineros_bot

Dineros accounts shared expenditures.
Invite him to your Telegram groups!
Even reckonings make long friends.

### Commands
* /cancelar - un comando interactivo
* /pago - gasto compartido
* /pago_desigual - gasto no tan compartido
* /préstamo - transferencia entre dos
* /balance - estado de las cuentas
* /usuarios - gestión del grupo

### TODO
Private chat:
1. Quick calculator for one-time situations
2. Categories for complex quick calculations
3. General balance (individuals and groups)

Group chat:
1. Accounting for projects

General:
1. /explain
2. Balance aggregation to reduce DB stress
3. True i18n (commands, money, etc.)
4. Periodic remainders (rent, bills, etc.)
5. Payment follow-ups
6. Payment templates (same participants)
7. Monthly balance auto-calculation
8. 'Next payer' recommendation
9. Basic math operands
10. Numeral separators regexp.

## Users

### Creation

Under the command /users the user is prompted about the desired action.
- Create real user.
- Create virtual user.
- Take control of a virtual user.
- Delete user.

Automatic actions:
- Demote to virtual user, when a real user leaves the conversation.
- Promote to real user or create real user, when a user enters a conversation.

### Deletion

- Delete payment => link
- Delete user => remove from group, sets it to virtual
- Delete virtual user => it must have zero balance

  - It can't be removed, it's hidden instead. The user
    can be reactivated or even reassigned to a real user.

    Ways of hiding a user: 'active' field or alias nullification.
    The last one seems more attractive since it does not require
    to add another field to the alias table and does not capture
    the alias; the bad side is that the not null constraint of the
    alias column should be raised.

  - It can be removed, transactions are assigned
    to an anonymous user. They cannot be recovered
    afterwards.

  Delete virtual user implies to delete its transactions,
  which in principle it cannot be done, except by removing
  all transactions of a group, which then is equivalent to
  stop using Dineros.

  The idea of not deleting virtual users is to be able to
  explain past transactions. It could be done with anonymous
  users. One wants to delete virtual users in first place to
  not show them in balance reports nor select menus in payments.

  All in all is not convenient to delete or occult a user with
  a balance distinct of zero, as this has an effect on the other
  users balances. Group balance as a whole always must sum zero.

  user_id  alias  status
  -------  -----  ------
  yes      yes    real
  yes      no     -
  no       yes    virtual
  no       no     inactive

- Delete everything => remove Dineros
