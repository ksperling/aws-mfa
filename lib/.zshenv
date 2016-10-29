function aws() {
  # Refresh credentials via aws-mfa if necessary (check via `date` first as it's faster)
  if ! [[ "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" < "$AWS_SESSION_EXPIRATION" ]]; then
    local credentials="$("$AWS_MFA")" rc=$?
    [ $rc -eq 0 ] || return $rc
    eval "$credentials"
  fi
  command aws "$@"
}

test -f "${AWS_MFA_ZDOTREAL:-${HOME}}/.zshenv" && source "${AWS_MFA_ZDOTREAL:-${HOME}}/.zshenv"
