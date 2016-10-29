test -f "${AWS_MFA_ZDOTREAL:-${HOME}}/.zshrc" && source "${AWS_MFA_ZDOTREAL:-${HOME}}/.zshrc"
PS1="(aws) $PS1"

ZDOTDIR="$AWS_MFA_ZDOTREAL"
unset AWS_MFA_ZDOTREAL
