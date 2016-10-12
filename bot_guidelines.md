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

---

a. Machines shall initialize in a final_state. If the command is interactive
the state will change to something accordingly.
