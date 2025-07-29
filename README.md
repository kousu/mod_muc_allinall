# mod_muc_allinall
An module for the prosody XMPP server to place all users in your server in all chats on your server; best used with mod_roster_allinall which makes all local users contacts.

⚠️ WIP !

## Install

I intend to get this promoted to [prosody community modules](https://prosody.im/community_modules), but until then you should

Base:

1. Have prosody
2. [Install the community modules](https://prosody.im/doc/installing_modules)
  1. This usually involves editing `/etc/prosody.cfg.lua` to include `plugin_paths = { "/usr/local/lib/prosody/modules" }`
  2. Then `hg clone`ing into that path 

This:

4. Edit `/etc/prosody.cfg.lua` again to add a new path: `plugin_paths = { [...]; "/usr/local/lib/prosody/alt-modules" }`
5. Download this repo: `git clone https://github.com/kousu/mod_muc_allinall/ /usr/local/lib/prosody/alt-modules/mod_muc_allinall`
6. In your prosody config, under whatever VirtualHost you want this active on:

    ```
    modules_enabled = {
      -- [...]
      "muc_allinall";
      -- [...]
    };

    -- [...]
    muc_allinall_host = "chats.your.domain"; -- set this to the domain your "muc" component is running on
    ```

I suppose you could also edit


## Behaviour

- Whenever a user logs in their chatroom bookmarks are updated to match the currently existing chatrooms
- Whenever a chatroom is created or destroyed, all users bookmarks are updated to match

## Alternatives

The prosody.im/snikket.im team are working on making "Circles" which are pretty similar, but more flexible. They allow you to make groups of users that are all in the same chatrooms and all on each others contact lists. It's implemented in snikket through four modules

- `groups` which handles adding people to each other's contact lists (like `roster_allinall`), but requires a manual config file of groups
- `groups_internal` which makes `groups` dynamic, editable via internal prosody API
- `groups_migration` which, despite it's name, is actually about syncing group membership on login
- `groups_muc_bookmarks` which handles
- user-facing joining groups is via `mod_adhoc_groups` or using the snikket web admin UI

These modules are loaded/configured in Snikket here:

* https://github.com/snikket-im/snikket-server/blob/e925a895bf88d7228ae5b491744941609d2c443c/ansible/files/prosody.cfg.lua#L134-L137
* https://github.com/snikket-im/snikket-server/blob/e925a895bf88d7228ae5b491744941609d2c443c/ansible/files/prosody.cfg.lua#L204

Unfortunately they're currently underdocumented and **too** flexible! They work great _as part of Snikket_, but if you have a customized Prosody
they don't work. For example `mod_groups_migration` gets confused if combined with `mod_auth_ldap`. They're also too hard to configure. There's no prosodyctl interface to them yet, only the web interface, and that's pretty heavy. So it's replaced an admin ssh'ing in and editing a file with an admin logging in to a web interface or using a REST API. In either case, users can't self-manage and an admin has to be involved to onboard ever new user. Maybe `mod_adhoc_groups` works well, I don't know, I haven't tried that, but I know if that's involved there's AT LEAST the step of trying to explain wtf an ad hoc xmpp command is to new users.

This module takes the approach that `mod_roster_allinall` takes: for a small server where everyone more or less knows each other, just put everyone in every chat.  Except for private ("hidden") chats, this module leaves those alone. This is the behaviour people expect from Discord -- though not the behaviour they expect from Slack -- and it hopefully should cut through the red tape of onboarding an existing community to xmpp.
