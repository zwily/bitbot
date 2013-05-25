# Bitbot

An IRC bit-tip style bot. Just for fun, don't use with lots of coins.

## Security

**You probably don't want to use this.**

This section is first because anything Bitcoin related seems to attract
l33t hax0rs. This is just a toy. You probably shouldn't use it, and if
you do, you shouldn't put much money into it. Here's why:

Bitbot does not operate on nicknames, but usernames. Therefore, it's
only secure on IRC networks where usernames are forced. This probably
isn't true of whatever IRC network you're on. (On our IRC network,
usernames cannot be spoofed.) In order to be secure, the bot would need
to authenticate users in some other way, perhaps by using NickServ or
something. Pull requests accepted.

Bitbot uses an online wallet at https://blockchain.info . This was
because it was the easiest path forward, but it is not the most secure.
Blockchain.info itself seems reasonably secure, but if someone were to
breach its servers, they would be able to steal all the coins stored by
Bitbot. A better setup would be for Bitbot to perform its own
transactions on the Bitcoin network. Pull requests accepted. :)

Bitbot is based on a Ruby IRC library called
[Cinch](https://github.com/cinchrb/cinch). I have no idea how secure
Cinch is - it's possible that it has a remote code execution
vulnerability. If it does, an attacker can steal all the coins from
Bitbot.

Hopefully the above has scared you off from installing this and using it
on Freenode. If it didn't, then you deserve to lost whatever you put in.
You could just send it to me directly instead:
1zachsQ82fM7DC4HZQXMAAmkZ2Qg7pH2V.

## How Does It Work

Bitbot lets people in IRC send each other Bitcoin. It's loosely modelled
after the [Reddit Bitcointip](http://redd.it/13iykn).

The big difference is that in Bitbot, tips between users do not show up
in the blockchain. Bitbot maintains a wallet with all of the deposited
funds, and then keeps a record of transactions between users. Only
deposits and withdrawals to and from Bitbot show up in the Bitcoin
blockchain.

We do this because our tips are generally pretty tiny, and if each one
were a real transaction, our entire "Bitconomy" would be eaten up by
transaction fees.

## Installation

 * Install the dependencies (sqlite3)
 * 
 * Install the gem:

```bash
gem install bitbot
```

 * Create an online wallet at https://blockchain.info/wallet/ . Create a
   secondary password on it, and I suggest locking access to the IP from
   which your bot will be running for an little extra security. It's
   probably also good to set up (encrypted) wallet backups to go to your
   email address.

 * Create a config.yml file that looks like this:

```yaml
irc:
  server: irc.example.com
  port: 8765
  ssl: true
  nick: bitbot
  username: bitbot@example.com
  password: blahblah

blockchain:
  wallet_id: <long guid>
  password1: <password>
  password2: <secondary password>

database:
  path: <path to database>
```

 * Start the bot:

```bash
$ bitbot <path to config.yml> 

## Usage

### Help

To get help, `/msg bitbot help`. He will respond with a list of commands
he supports:

```
bitbot: Commands: deposit, balance, history, withdrawal
```

### Deposit

To make a deposit to your Bitbot account, ask bitbot for your depositing
address: `/msg bitbot deposit`. Bitbot will respond with a Bitcoin
address to send coins to. Once 

### Tipping

To tip somebody, you must both be in a room with Bitbot. The syntax is
`+tip <nickname> <amount in BTC> <message>`. When Bitbot sees that, it
verifies that you have the funds to tip, does a `whois` on the recipient
nickname, and then transfers the funds. He then responds with a
confirmation:

```
bob: how do i make rails tests fast?
john: refactor your app so you can test it without rails
bob: +tip john 0.01 ur so smart
bitbot:  [✔] Verified: bob ➜ ฿+0.01 [$1.12] ➜ john
```

### Withdrawing

When you want to withdraw funds to another Bitcoin address, just tell
Bitbot: `/msg bitbot withdraw <amount> <address>`. 

Bitbot will verify that you have enough money, and send `<amount>` BTC -
0.0005 (to cover the transaction fee) to the specified `<address>`.
