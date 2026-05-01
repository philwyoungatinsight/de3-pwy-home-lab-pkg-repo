# Goal
- Deal with Terraform-Sops integration showing
  the gpg passphrase challenge too often.

# Options

# Option: Tell sops to not use GPG 
# use, for example, AGE, instead
export SOPS_GPG_EXEC=false

# Option: Increase the gpg-agent timeout
# Add to ~/.gnupg/gpg-agent.conf
default-cache-ttl 34560000
max-cache-ttl 34560000

# Option: Kill and restart gpg agent
export GPG_TTY=$(tty)
gpgconf --kill gpg-agent
gpg-connect-agent reloadagent /bye
