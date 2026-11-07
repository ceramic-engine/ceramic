<!DOCTYPE html>
<html>
<body>
<?php
namespace App;

use App\Models\User;

/** A function. */
function greet(string $name, int $times = 2): string {
    $out = "Hello {$name}";
    return str_repeat($out . "\n", $times);
}

echo greet('world'), PHP_EOL; // comment
?>
<p class="note">Done</p>
</body>
</html>
