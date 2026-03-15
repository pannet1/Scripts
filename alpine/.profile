if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s)
    ssh -V
    ls -la ~/.ssh
fi

export PATH=$PATH:~/Scripts/client/:/Scripts/alpine/:
