<?php
// trusted-proxy.php -- normalize $_SERVER from reverse-proxy headers.
//
// Loaded as a PHP auto_prepend_file (see the image's php config). When TLS is
// terminated by an upstream proxy/ingress, the PHP backend sees the plaintext
// port (usually 80) even though the public scheme is https. HotCRP derives the
// scheme from X-Forwarded-Proto but the port from SERVER_PORT, so it builds
// absolute URLs like "https://host:80/...". Rewriting SERVER_PORT (and the
// scheme markers) here, before HotCRP inspects $_SERVER, fixes those URLs.
//
// Enabled only when HOTCRP_TRUST_PROXY is truthy, so it is a no-op for
// directly-exposed deployments where forwarded headers must not be trusted.
// Placed in the public domain.

if (filter_var(getenv("HOTCRP_TRUST_PROXY") ?: "", FILTER_VALIDATE_BOOLEAN)) {
    $first = static function ($v) {
        return trim(explode(",", $v)[0]);
    };

    if (!empty($_SERVER["HTTP_X_FORWARDED_PROTO"])) {
        $proto = strtolower($first($_SERVER["HTTP_X_FORWARDED_PROTO"]));
        if ($proto === "https") {
            $_SERVER["HTTPS"] = "on";
            $_SERVER["REQUEST_SCHEME"] = "https";
            $_SERVER["SERVER_PORT"] = "443";
        } else if ($proto === "http") {
            unset($_SERVER["HTTPS"]);
            $_SERVER["REQUEST_SCHEME"] = "http";
            $_SERVER["SERVER_PORT"] = "80";
        }
    }

    // A non-standard public port overrides the scheme default set above.
    if (!empty($_SERVER["HTTP_X_FORWARDED_PORT"])) {
        $port = $first($_SERVER["HTTP_X_FORWARDED_PORT"]);
        if (ctype_digit($port)) {
            $_SERVER["SERVER_PORT"] = $port;
        }
    }

    if (!empty($_SERVER["HTTP_X_FORWARDED_HOST"])) {
        $_SERVER["HTTP_HOST"] = $first($_SERVER["HTTP_X_FORWARDED_HOST"]);
    }
}
