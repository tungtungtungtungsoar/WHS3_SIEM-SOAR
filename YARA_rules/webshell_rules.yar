rule webshell_base64_func
{
		meta:
				description = "PHP webshell using base64"
		strings:
				$php = "<?php"
				$b64 = "base64_decode"
				$var_func = /\$\w+\s*\(/
				$get = /\$_(GET|POST|REQUEST)\['cmd'\]/
		condition:
				all of them
}