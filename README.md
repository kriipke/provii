# provii

`provii` is an extremely lightweight installer for command-line tools & utilities written in pure bash.

## Suggested Uses

 - quickly install software on machines on which you do not have the permissions required to use a package manager
 - test out new cli utitilies / tools before installing them without mucking up your system or installing unneeded packages 
 - use in provisioning workflows, e.g. Packer, Ansible
 - accompaniment to a dotfile management system such as [dotdrop](https://github.com/deadc0de6/dotdrop), to automatically ensure the utilie on which your dotfiles depend on the machine before you deploy them

## Design Constraints

*TO-DO*

The design goals are:
 - *minimal footprint*: provii itself along with the tools it installs should be extremely easy to keep track of on your filesystem and consequently easy to remove
 - *minimal dependencies*: to keep things portable as well as keep the footprint to a minimum provii is designed to install binary applications via it's installation scripts 
 - *minimal privilages required*: you should be able to run these installations as any user with the option of installing them system wide if you run provii with root privilages.

You can find more information on provii at https://l0xy.sh/code/provii

## Usage

There are two ways to use `provii`:
 - pull the script straight down from either github or https://l0xy.sh/provii and pipe it in to bash
 - download it and use it as you would a typical executable shell script

Regardless of which method you use `provii` with the inveitably run to install the piece of software you choose will be pulled from [this github repository](https://github.com/l0xy/provii).

So you can peruse the "installs" directory containing all the scripts, or run `provii ls` to get more information about what software is availaible via `provii`

### Option 1: on-the-go usage (curl) 

A neat part about `provii` is that you don't actually have to install it to get access to the cool binaries it's openshe door too, i.e. command-line utilities & tools. giving it a single argument, namely the program you want to fetch, e.g. in the case of `kmon` -- a utility for monitoring loaded kernel modules -- run the following in your terminal:

`bash -c "$(curl https://l0xy.sh/provii)" kmon` 

### Option 2: on-the-go usage (curl) 

The second way to use `provii` is to download the script as file on your machine, make it executable. For example, on unix machines:

```bash
curl -sS https://l0xy.sh/provii > /tmp/provii
sudo install /tmp/provii /usr/local/bin
```

or if you don't have administrative rights to the machine you're on:

```bash
curl -sS https://l0xy.sh/provii > /tmp/provii
echo "PATH=$HOME/.local/bin:$PATH" > ~/.bashrc
mkdir -p $HOME/.local/bin
install /tmp/provii $HOME/.local/bin
```

After installing the script you should be able use it like any other command-line tool, a great place to start is:

`provii --help`

Also see:

`provii ls`
`provii install`
`provii vars`
`provii cat`

