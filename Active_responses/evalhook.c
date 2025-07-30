
//100503 evalhook으로 난독화된 웹쉘 탐지

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "php.h"
#include "php_ini.h"
#include "ext/standard/info.h"
#include "zend_compile.h"
#include "php_evalhook.h"

PHP_MINIT_FUNCTION(evalhook);
PHP_MSHUTDOWN_FUNCTION(evalhook);
PHP_MINFO_FUNCTION(evalhook);

zend_module_entry evalhook_module_entry = {
    STANDARD_MODULE_HEADER,
    "evalhook",
    NULL,
    PHP_MINIT(evalhook),
    PHP_MSHUTDOWN(evalhook),
    NULL,
    NULL,
    PHP_MINFO(evalhook),
    "0.1",
    STANDARD_MODULE_PROPERTIES
};

#ifdef COMPILE_DL_EVALHOOK
ZEND_GET_MODULE(evalhook)
#endif

static zend_op_array *(*orig_compile_string)(zend_string *source_string, const char *filename);
static zend_bool evalhook_hooked = 0;

static zend_op_array *evalhook_compile_string(zend_string *source_string, const char *filename)
{
    const char *code = ZSTR_VAL(source_string);
    size_t len = ZSTR_LEN(source_string);

    char base_filename[PATH_MAX];
    strncpy(base_filename, filename, sizeof(base_filename) - 1);
    base_filename[sizeof(base_filename) - 1] = '\0';  // null-terminate 안전하게
    char *paren = strchr(base_filename, '(');
    if (paren != NULL) {
        *paren = '\0';
    }

    php_printf("\n=============[webshell_detected]=============\n");
    php_printf("Payload:\n%.*s\n", (int)len, code);

    const char *signatures[] = {
        "eval", "assert", "system", "shell_exec", "passthru", "exec", "proc_open", "popen",
        "$_GET", "$_POST", "$_REQUEST", "$_COOKIE", "$_FILES",
        "base64_decode", "gzinflate", "str_rot13", "chr"
    };
    int sig_count = sizeof(signatures) / sizeof(signatures[0]);

    char pattern_summary[1024] = "";
    int first = 1;

    for (int i = 0; i < sig_count; ++i) {
        if (strstr(code, signatures[i]) != NULL) {
            php_printf("[!!]⚠️Suspicious_pattern_detected:'%s'\n", signatures[i]);
            if (first) {
                snprintf(pattern_summary + strlen(pattern_summary), sizeof(pattern_summary) - strlen(pattern_summary), "%s", signatures[i]);
                first = 0;
            } else {
                snprintf(pattern_summary + strlen(pattern_summary), sizeof(pattern_summary) - strlen(pattern_summary), ",%s", signatures[i]);
            }
        }
    }

    if (strlen(pattern_summary) > 0) {
        php_printf("=============[webshell_summary]=============\n");
        php_printf("!!Pattern_matched:%s\n", pattern_summary);
        php_printf("⚠️Suspicious_file:%s\n", base_filename);
        php_printf("=============================================\n");
    }

    return orig_compile_string(source_string, filename);
}

PHP_MINIT_FUNCTION(evalhook)
{
    if (!evalhook_hooked) {
        orig_compile_string = zend_compile_string;
        zend_compile_string = evalhook_compile_string;
        evalhook_hooked = 1;
    }
    return SUCCESS;
}

PHP_MSHUTDOWN_FUNCTION(evalhook)
{
    if (evalhook_hooked) {
        zend_compile_string = orig_compile_string;
        evalhook_hooked = 0;
    }
    return SUCCESS;
}

PHP_MINFO_FUNCTION(evalhook)
{
    php_info_print_table_start();
    php_info_print_table_header(2, "evalhook support", "enabled");
    php_info_print_table_end();
}