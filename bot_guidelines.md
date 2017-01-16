# Some guidelines for designing Telegram bots

1. Every command shall be interactive

Think in two class of users: those who use your bot frequently and those who
are experimenting with it. Maybe you are used to manpages but for sure most
people is not willing to read a wall of text of how to interact with your bot.

If a command is provided as-is, without arguments, offer a step-by-step
conversation which guides the user throughout the whole process.
**Then at the end of the operation let the bot show how the same task could be
accomplished in a non-interactive way, with arguments.** Examples are the way
to go.

2. Non-interactive counterpart only if it is a frequent command

If the command is required once in a while there is no need of saving time or
effort. Consider also that is difficult to learn and easy to forget the
parameters of seldom used commands.

3. When creating a new bot, also ask for a development version

Botfather always knew about this but he will never tell you. Create
whatever_bot you want and also the we_dev_bot; your users will be grateful
of you not messing things up when doing maintenance or trying new features.
Maybe not a similar name for the development version so users do not chat
with it by mistake.

4. Manage two types of exceptions

In an interactive command you may want to abort the whole command
or ask the user to re-respond the last request, depending on the error.

5. Commands need to be canceled versus new command cancels previous command.



---

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

  user_id | alias | status
  ------- | ----- | ------
  yes     | yes   | real
  yes     | no    | -
  no      | yes   | virtual
  no      | no    | inactive

- Delete everything => remove Dineros
