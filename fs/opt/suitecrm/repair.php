#!/usr/bin/php
<?php

/*
 * Copyright 2013
 * Jeff Bickart
 * @bickart
 * jeff @ neposystems.com
 * 
 * Edited by Tuomas Liinamaa <tlii@iki.fi> 2022
 *  */

if (!defined('sugarEntry')) define('sugarEntry', true);

$dir_body = getenv("SUITECRM_INSTALL_DIR");
$dir_body = rtrim($dir_body, '/') . '/';
require_once($dir_body.'include/entryPoint.php');
require_once($dir_body.'modules/Administration/QuickRepairAndRebuild.php');

//Bug 27991 . Redirect to index.php if the request is not come from CLI.
$sapi_type = php_sapi_name();
if (substr($sapi_type, 0, 3) != 'cgi') {
    global $sugar_config;
    if (!empty($sugar_config['site_url'])) {
        header("Location: " . $sugar_config['site_url'] . "/index.php");
    } else {
        sugar_die("Didn't find site url in your sugarcrm config file");
    }
}
//End of #27991

if (empty($current_language)) {
    $current_language = $sugar_config['default_language'];
}

$app_list_strings = return_app_list_strings_language($current_language);
$app_strings = return_application_language($current_language);

global $current_user;
$current_user = new User();
$current_user->getSystemUser();

$GLOBALS['log']->debug('--------------------------------------------> at repair.php <--------------------------------------------');
$repair = new RepairAndClear();
$repair->repairAndClearAll(array('clearAll'), array(translate('LBL_ALL_MODULES')), true, false);

$exit_on_cleanup = true;

sugar_cleanup(false);

// some jobs have annoying habit of calling sugar_cleanup(), and it can be called only once
// but job results can be written to DB after job is finished, so we have to disconnect here again
// just in case we couldn't call cleanup
if (class_exists('DBManagerFactory')) {
    $db = DBManagerFactory::getInstance();
    $db->disconnect();
}

if ($exit_on_cleanup) exit;
