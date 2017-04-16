#!/usr/bin/php
<?php

exec('/usr/local/bin/gpio -g mode 4 pwm');

if (!file_exists('db')) mkdir('db');

$pwm_spin = 256;
$pwm_min = 128;
$pwm_max = 1024;
$cpu_min = 30; // 25
$cpu_max = 55;
$hdd_min = 35; //26
$hdd_max = 45;

$sample = 20;
$wait = 5;
$pwm = 0;

$last = 0;
while (true) {
	$now = time();
	$today = date('Ymd',$now);
	if ($now>$last+$sample) {
		$cpu = read_cpu();
		$hdd = read_hdd();
		$load = read_load();
		$mem = read_mem();
		
		$cpu_pwm = round(map( (float)$cpu, $cpu_min, $cpu_max, $pwm_min, $pwm_max));
		if ($cpu_pwm<$pwm_min) $cpu_pwn = 0;
		if ($cpu_pwm>$pwm_max) $cpu_pwn = $pwm_max;
		
		$hdd_pwm = round(map( (float)$hdd, $hdd_min, $hdd_max, $pwm_min, $pwm_max));
		if ($hdd_pwm<$pwm_min) $hdd_pwn = 0;
		if ($hdd_pwm>$pwm_max) $hdd_pwn = $pwm_max;

		$new_pwm = max($cpu_pwm,$hdd_pwm);
		
		if ($new_pwm>0) {
			if ($pwm<$pwm_min) {
				$pwm = $pwm_spin;
			} else  {
				$pwm = $new_pwm;
			}
		}
		if ($pwm>0 && $pwm<$pwm_min) $pwm = $pwm_min;
		exec("/usr/local/bin/gpio -g pwm 4 $pwm");
		$pwm_p = round($pwm/$pwm_max*100).'%';
		
		decho("pwm: $pwm_p	cpu: $cpu	hdd: $hdd	load: $load	mem: $mem[MemTotal] kB / $mem[MemFree] kB");
		$db = array(
			'timestamp' => $now,
			'pwm' => $pwm,
			'cpu' => $cpu,
			'hdd' => $hdd,
			'load' => $load,
			'mem' => $mem,
		);
		if (!file_exists("db/$today")) {
			mkdir("db/$today");
		}
		$json = json_encode($db);
		file_put_contents("db/latest.json",$json);
		file_put_contents("db/$today/$now.json",$json);
		$last = $now;
	} else {
		sleep($wait);
	}
}




function decho($msg) {
	echo date('Y-m-d H:i:s')."\t$msg\n";
}

function read_cpu() {
	$temp = file_get_contents('/sys/devices/platform/sunxi-i2c.0/i2c-0/0-0034/temp1_input')/1000;
	return number_format($temp,1)."°C";
}

function read_hdd() {
	$fp = fsockopen("127.0.0.1", 7634, $errno, $errstr, 30);
	if (!$fp) {
		return -1;
	} else {
		$str = '';
		while (!feof($fp)) {
			$str.=fgets($fp, 1024);
		}
		fclose($fp);
		list($t,$drive,$model,$temp,$deg) = explode('|',$str);
	}
	
	return $temp."°$deg";
}

function read_load() {
	list($load) = explode(' ',file_get_contents('/proc/loadavg'));	
	return number_format($load,2);
}

function read_mem() {
	$meminfo = file('/proc/meminfo');
	$mem = array();
	foreach ($meminfo as $m) {
		list($key,$val) = explode(':',$m);
		$key = trim($key);
		$mem[$key] = (int)$val;
	}
	return $mem;
}

function map($value, $fromLow, $fromHigh, $toLow, $toHigh) {
    $fromRange = $fromHigh - $fromLow;
    $toRange = $toHigh - $toLow;
    $scaleFactor = $toRange / $fromRange;

    // Re-zero the value within the from range
    $tmpValue = $value - $fromLow;
    // Rescale the value to the to range
    $tmpValue *= $scaleFactor;
    // Re-zero back to the to range
    return $tmpValue + $toLow;
}

?>