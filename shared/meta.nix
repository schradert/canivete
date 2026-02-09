{can, ...}: {
  options.canivete.meta = {
    domain = can.domain "base domain for exposing nodes and services" {};
    people = can.submodule "people in the organization" ({config, ...}: {
      options.users = can.attrs.submodule "all of the users to create configurations for" {
        options.name = can.str "name of the user to default to in all contexts" {example = "John Doe";};
        options.accounts = can.attrs.str "mapping of external program names to user account" {};
        options.profiles = can.attrs.submodule "details on user profiles" {
          options.email = can.email "user profile email" {};
          options.sshPubKey = can.str "public key for connecting to nodes and services and accounts" {};
        };
      };
      options.me = can.enum (builtins.attrNames config.users) "the super admin user in all contexts" {};
      options.my = can.raw "user details associated with 'me'" {default = config.users.${config.me};};
    });
  };
}
