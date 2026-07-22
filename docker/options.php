<?php
// docker/options.php -- HotCRP configuration for the container image.
//
// Every value is read from the environment so the same image can be pointed at
// any database and conference. See docker-compose.yml for the variable names.
// Placed in the public domain.

global $Opt;

/** @return ?string */
function hotcrp_env($name, $default = null) {
    $v = getenv($name);
    return $v === false || $v === "" ? $default : $v;
}

// Database connection.
$Opt["dbHost"] = hotcrp_env("HOTCRP_DB_HOST", "db");
$Opt["dbName"] = hotcrp_env("HOTCRP_DB_NAME", "hotcrp");
$Opt["dbUser"] = hotcrp_env("HOTCRP_DB_USER", $Opt["dbName"]);
$Opt["dbPassword"] = hotcrp_env("HOTCRP_DB_PASSWORD", "");

// Conference identity.
$Opt["shortName"] = hotcrp_env("HOTCRP_CONF_SHORTNAME", "HotCRP");
$Opt["longName"] = hotcrp_env("HOTCRP_CONF_LONGNAME", $Opt["shortName"]);
if (($site = hotcrp_env("HOTCRP_PAPER_SITE")) !== null) {
    $Opt["paperSite"] = $site;
}

// Site contact / outgoing email.
$Opt["contactName"] = hotcrp_env("HOTCRP_CONTACT_NAME", "HotCRP Administrator");
$Opt["contactEmail"] = hotcrp_env("HOTCRP_CONTACT_EMAIL", "admin@example.com");
$Opt["emailFrom"] = hotcrp_env("HOTCRP_EMAIL_FROM", $Opt["contactEmail"]);
// Sending mail requires an SMTP relay (see HOTCRP_SMTP_* / docker/entrypoint.sh).
// Default sendEmail on when a relay is configured, otherwise off.
$Opt["sendEmail"] = filter_var(hotcrp_env("HOTCRP_SEND_EMAIL", hotcrp_env("HOTCRP_SMTP_HOST") ? "true" : "false"), FILTER_VALIDATE_BOOLEAN);
if (($sender = hotcrp_env("HOTCRP_EMAIL_SENDER")) !== null) {
    $Opt["emailSender"] = $sender;
}

// Store uploaded papers on the local filesystem (mount a volume at ./docs).
// Set HOTCRP_DOCSTORE=0 to keep documents in the database instead.
if (filter_var(hotcrp_env("HOTCRP_DOCSTORE", "true"), FILTER_VALIDATE_BOOLEAN)) {
    $Opt["docstore"] = hotcrp_env("HOTCRP_DOCSTORE_PATH", "docs");
}

// Behavior defaults matching etc/distoptions.php.
$Opt["smartScoreCompare"] = true;
$Opt["authorSharing"] = 0;

// Redirect HTTP to HTTPS when the deployment terminates TLS itself.
if (filter_var(hotcrp_env("HOTCRP_REDIRECT_HTTPS", "false"), FILTER_VALIDATE_BOOLEAN)) {
    $Opt["redirectToHttps"] = true;
}

// Trust proxy headers so session cookies are marked secure behind a TLS proxy.
if (filter_var(hotcrp_env("HOTCRP_SESSION_SECURE", "false"), FILTER_VALIDATE_BOOLEAN)) {
    $Opt["sessionSecure"] = true;
}

// Load any additional per-conference overrides mounted into conf/ (e.g.
// conf/local.conf.php). options.php itself is already loaded, so it is skipped.
$Opt["include"] = "conf/*.conf.php";
