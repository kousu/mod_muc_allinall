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

4. Edit `/etc/prosody.cfg.lua` again to include `plugin_paths = { [...], "/usr/local/lib/prosody/alt-modules" }`
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
