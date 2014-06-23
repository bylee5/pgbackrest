####################################################################################################################################
# UTILITY MODULE
####################################################################################################################################
package BackRest::Utility;

use threads;

use strict;
use warnings;
use Carp;
use Fcntl qw(:DEFAULT :flock);
use File::Path qw(remove_tree);
use File::Basename;

use lib dirname($0) . "/../lib";
use BackRest::Exception;

use Exporter qw(import);

our @EXPORT = qw(version_get
                 data_hash_build trim common_prefix wait_for_file date_string_get file_size_format execute
                 log log_file_set log_level_set
                 lock_file_create lock_file_remove
                 TRACE DEBUG ERROR ASSERT WARN INFO OFF true false);

# Global constants
use constant
{
    true  => 1,
    false => 0
};

use constant
{
    TRACE  => 'TRACE',
    DEBUG  => 'DEBUG',
    INFO   => 'INFO',
    WARN   => 'WARN',
    ERROR  => 'ERROR',
    ASSERT => 'ASSERT',
    OFF    => 'OFF'
};

my $hLogFile;
my $strLogLevelFile = ERROR;
my $strLogLevelConsole = ERROR;
my %oLogLevelRank;

my $strLockPath;
my $hLockFile;

$oLogLevelRank{TRACE}{rank} = 6;
$oLogLevelRank{DEBUG}{rank} = 5;
$oLogLevelRank{INFO}{rank} = 4;
$oLogLevelRank{WARN}{rank} = 3;
$oLogLevelRank{ERROR}{rank} = 2;
$oLogLevelRank{ASSERT}{rank} = 1;
$oLogLevelRank{OFF}{rank} = 0;

####################################################################################################################################
# VERSION_GET
####################################################################################################################################
my $strVersion;

sub version_get
{
    my $hVersion;
    my $strVersion;

    if (!open($hVersion, "<", dirname($0) . "/../VERSION"))
    {
        confess &log(ASSERT, "unable to open VERSION file");
    }

    if (!($strVersion = readline($hVersion)))
    {
        confess &log(ASSERT, "unable to read VERSION file");
    }

    close($hVersion);

    return trim($strVersion);
}

####################################################################################################################################
# LOCK_FILE_CREATE
####################################################################################################################################
sub lock_file_create
{
    my $strLockPathParam = shift;

    my $strLockFile = $strLockPathParam . "/process.lock";

    if (defined($hLockFile))
    {
        confess &lock(ASSERT, "${strLockFile} lock is already held");
    }

    $strLockPath = $strLockPathParam;

    unless (-e $strLockPath)
    {
        if (system("mkdir -p ${strLockPath}") != 0)
        {
            confess &log(ERROR, "Unable to create lock path ${strLockPath}");
        }
    }

    sysopen($hLockFile, $strLockFile, O_WRONLY | O_CREAT)
        or confess &log(ERROR, "unable to open lock file ${strLockFile}");

    if (!flock($hLockFile, LOCK_EX | LOCK_NB))
    {
        close($hLockFile);
        return 0;
    }

    return $hLockFile;
}

####################################################################################################################################
# LOCK_FILE_REMOVE
####################################################################################################################################
sub lock_file_remove
{
    if (defined($hLockFile))
    {
        close($hLockFile);

        remove_tree($strLockPath) or confess &log(ERROR, "unable to delete lock path ${strLockPath}");

        $hLockFile = undef;
        $strLockPath = undef;
    }
    else
    {
        confess &log(ASSERT, "there is no lock to free");
    }
}

####################################################################################################################################
# DATA_HASH_BUILD - Hash a delimited file with header
####################################################################################################################################
sub data_hash_build
{
    my $oHashRef = shift;
    my $strData = shift;
    my $strDelimiter = shift;
    my $strUndefinedKey = shift;

    my @stryFile = split("\n", $strData);
    my @stryHeader = split($strDelimiter, $stryFile[0]);

    for (my $iLineIdx = 1; $iLineIdx < scalar @stryFile; $iLineIdx++)
    {
        my @stryLine = split($strDelimiter, $stryFile[$iLineIdx]);

        if (!defined($stryLine[0]) || $stryLine[0] eq "")
        {
            $stryLine[0] = $strUndefinedKey;
        }

        for (my $iColumnIdx = 1; $iColumnIdx < scalar @stryHeader; $iColumnIdx++)
        {
            if (defined(${$oHashRef}{"$stryHeader[0]"}{"$stryLine[0]"}{"$stryHeader[$iColumnIdx]"}))
            {
                confess "the first column must be unique to build the hash";
            }

            if (defined($stryLine[$iColumnIdx]) && $stryLine[$iColumnIdx] ne "")
            {
                ${$oHashRef}{"$stryHeader[0]"}{"$stryLine[0]"}{"$stryHeader[$iColumnIdx]"} = $stryLine[$iColumnIdx];
            }
        }
    }
}

####################################################################################################################################
# TRIM - trim whitespace off strings
####################################################################################################################################
sub trim
{
    my $strBuffer = shift;

    if (!defined($strBuffer))
    {
        return undef;
    }

    $strBuffer =~ s/^\s+|\s+$//g;

    return $strBuffer;
}

####################################################################################################################################
# WAIT_FOR_FILE
####################################################################################################################################
sub wait_for_file
{
    my $strDir = shift;
    my $strRegEx = shift;
    my $iSeconds = shift;

    my $lTime = time();
    my $hDir;

    while ($lTime > time() - $iSeconds)
    {
        opendir $hDir, $strDir or die "Could not open dir: $!\n";
        my @stryFile = grep(/$strRegEx/i, readdir $hDir);
        close $hDir;

        if (scalar @stryFile == 1)
        {
            return;
        }

        sleep(1);
    }

    confess &log(ERROR, "could not find $strDir/$strRegEx after $iSeconds second(s)");
}

####################################################################################################################################
# COMMON_PREFIX
####################################################################################################################################
sub common_prefix
{
    my $strString1 = shift;
    my $strString2 = shift;

    my $iCommonLen = 0;
    my $iCompareLen = length($strString1) < length($strString2) ? length($strString1) : length($strString2);

    for (my $iIndex = 0; $iIndex < $iCompareLen; $iIndex++)
    {
        if (substr($strString1, $iIndex, 1) ne substr($strString2, $iIndex, 1))
        {
            last;
        }

        $iCommonLen ++;
    }

    return $iCommonLen;
}

####################################################################################################################################
# FILE_SIZE_FORMAT - Format file sizes in human-readable form
####################################################################################################################################
sub file_size_format
{
    my $lFileSize = shift;

    if ($lFileSize < 1024)
    {
        return $lFileSize . "B";
    }

    if ($lFileSize < (1024 * 1024))
    {
        return int($lFileSize / 1024) . "KB";
    }

    if ($lFileSize < (1024 * 1024 * 1024))
    {
        return int($lFileSize / 1024 / 1024) . "MB";
    }

    return int($lFileSize / 1024 / 1024 / 1024) . "GB";
}

####################################################################################################################################
# DATE_STRING_GET - Get the date and time string
####################################################################################################################################
sub date_string_get
{
    my $strFormat = shift;

    if (!defined($strFormat))
    {
        $strFormat = "%4d%02d%02d-%02d%02d%02d";
    }

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

    return(sprintf($strFormat, $year+1900, $mon+1, $mday, $hour, $min, $sec));
}

####################################################################################################################################
# LOG_FILE_SET - set the file messages will be logged to
####################################################################################################################################
sub log_file_set
{
    my $strFile = shift;

    unless (-e dirname($strFile))
    {
        mkdir(dirname($strFile)) or die "unable to create directory for log file ${strFile}";
    }

    $strFile .= "-" . date_string_get("%4d%02d%02d") . ".log";
    my $bExists = false;

    if (-e $strFile)
    {
        $bExists = true;
    }

    open($hLogFile, '>>', $strFile) or confess "unable to open log file ${strFile}";

    if ($bExists)
    {
        print $hLogFile "\n";
    }

    print $hLogFile "-------------------PROCESS START-------------------\n";
}

####################################################################################################################################
# LOG_LEVEL_SET - set the log level for file and console
####################################################################################################################################
sub log_level_set
{
    my $strLevelFileParam = shift;
    my $strLevelConsoleParam = shift;

    if (defined($strLevelFileParam))
    {
        if (!defined($oLogLevelRank{"${strLevelFileParam}"}{rank}))
        {
            confess &log(ERROR, "file log level ${strLevelFileParam} does not exist");
        }

        $strLogLevelFile = $strLevelFileParam;
    }

    if (defined($strLevelConsoleParam))
    {
        if (!defined($oLogLevelRank{"${strLevelConsoleParam}"}{rank}))
        {
            confess &log(ERROR, "console log level ${strLevelConsoleParam} does not exist");
        }

        $strLogLevelConsole = $strLevelConsoleParam;
    }
}

####################################################################################################################################
# LOG - log messages
####################################################################################################################################
sub log
{
    my $strLevel = shift;
    my $strMessage = shift;
    my $iCode = shift;

    my $strMessageFormat = $strMessage;

    if (!defined($oLogLevelRank{"${strLevel}"}{rank}))
    {
        confess &log(ASSERT, "log level ${strLevel} does not exist");
    }

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

    if (!defined($strMessageFormat))
    {
        $strMessageFormat = "(undefined)";
    }

    if ($strLevel eq "TRACE")
    {
        $strMessageFormat =~ s/\n/\n                                           /g;
        $strMessageFormat = "        " . $strMessageFormat;
    }
    elsif ($strLevel eq "DEBUG")
    {
        $strMessageFormat =~ s/\n/\n                                       /g;
        $strMessageFormat = "    " . $strMessageFormat;
    }
    else
    {
        $strMessageFormat =~ s/\n/\n                                   /g;
    }

    $strMessageFormat = sprintf("%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec) .
                        sprintf(" T%02d", threads->tid()) .
                        (" " x (7 - length($strLevel))) . "${strLevel}: ${strMessageFormat}" .
                        (defined($iCode) ? " (code ${iCode})" : "") . "\n";

    if ($oLogLevelRank{"${strLevel}"}{rank} <= $oLogLevelRank{"${strLogLevelConsole}"}{rank})
    {
        print $strMessageFormat;
    }

    if ($oLogLevelRank{"${strLevel}"}{rank} <= $oLogLevelRank{"${strLogLevelFile}"}{rank})
    {
        if (defined($hLogFile))
        {
            print $hLogFile $strMessageFormat;
        }
    }

    if (defined($iCode))
    {
        return BackRest::Exception->new(iCode => $iCode, strMessage => $strMessage);
    }

    return $strMessage;
}

1;