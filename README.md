# provii

This is a little command-line utility installer that is written in pure bash. The design goals are:
 - *minimal footprint*: provii itself along with the tools it installs should be extremely easy to keep track of on your filesystem and consequently remove
 - *minimal dependencies*: to keep things portable as well as keep the footprint to a minimum provii is designed to install binary applications via it's installation scripts 
 - *minimal privilages required*: you should be able to run these installations as any user with the option of installing them system wide if you have access to directories like `/usr/local/bin`
 - *modular*: you should be able to easily add and remove functionality to your install scripts but dropping the path to any bash file containing variables or functions you want available in your installation scripts by adding `. /path/to/script` in the `lib/_ENV_.sh` file
 - *highly configurable*: you should be able customize exactly where everything installs to in order to fit the setup of your system by using the `provii.conf` file

## installation

For now, symlink the provii executable somewhere in your path changing the name to `iinst`. This alias for provii will allow you to run installation scripts as arguments directly. For example:
`ln -s ./provii /usr/local/bin/iinst`

..and to install the fd command by running the script in `./installs/fd`, for example, run:
`iinst fd`

Simple as that!

## writing scripts

The scripts are run in a bash subshell so any bash is fair game! Some special functions and variables have been added to the environment of the subshell to make writing the scripts easier and more portable.

### provii variables

TO BE DOCUMENTED..
( _check out the variables in `./provii.conf` to get a feel for the special provii variables_ )

### provii functions

TO BE DOCUMENTED..
( _check out the files in `./installs/` to get a feel for some of the special provii functions_ )
