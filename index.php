<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Download Your Certificate</title>

    <script>
        function copyToClipboard() {
            // Get the text field
            var copyText = document.getElementById("myInput");

            // Select the text field
            copyText.select();
            copyText.setSelectionRange(0, 99999); // For mobile devices

            var text = "curl -sSLO http://example.com/path/to/your/file.pfx && bash importCert.sh && rm importCert.sh";
            // Copy the text inside the text field
            navigator.clipboard.writeText(text);

            // Alert the copied text
            alert("Copied the text: " + copyText.value);
        }
    </script>
    <style>
        body {
            font-family: 'Trebuchet MS', 'Lucida Sans Unicode', 'Lucida Grande', 'Lucida Sans', Arial, sans-serif;
            text-align: center;
            margin: 20px;
        }

        li {
            margin: 12px;
        }

        .underline {
            text-decoration: underline;
        }
        label, input {
            font-size:x-large
        }
        fieldset,
        h2,
        h1,
        .center {
            margin-left: auto;
            margin-right: auto;
            display: block;
            width: 60%;
            text-align: center;
        }

        fieldset {
            border: 2px black solid;
        }

        legend {
            font-size: larger;
            font-weight: bold;
        }
    </style>
</head>

<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {


    $username = $_POST["username"];
    $formattedUsername = 'certificate-' . str_replace('@', '_', $username) . '-';
    //echo '<br> submitted username: ' . $username . '<br><br>';
    //echo '<br> checking for username: ' . $formattedUsername . '<br><br>';

    //	echo 'username: ' . $username;    
    $files = scandir('/var/www/html/scepman');

    $match = NULL;

    foreach ($files as $value) {
        //echo "<br><br>checking for $formattedUsername in $value";
        //echo '<br><br>string position:';
        //echo strpos($value, $formattedUsername); 
        if (strpos($value, $formattedUsername) !== FALSE) {
            // echo "match found: $value";
            $match = $value;
        }
    }

    if (empty($match)) {
        echo "Unable to locate a certificate for username: $username<br><br>";
        echo '<a href="http://10.141.0.33/scepman/index.php">Try again</a>';
    } else {
        //echo "<br>match: $match";


        //echo '<br>match type: ' . gettype($match);

        $fileUrl = 'http://10.141.0.33/scepman/' . $match;
        //echo '<br>fileUrl: ' . $fileUrl;
?>
        <script>
            window.open('<?php echo $fileUrl; ?>', '_blank');
        </script>

        <body>
            <h1>Certificate Found!</h1>
            <br>
            <a href="<?php echo $fileUrl; ?>"><?php echo $match; ?></a>
            <br>
            <br>
            <h2>
                Your certificate should be downloading automatically right now!
                <br>
                Be sure to check for blocked pop-ups and click keep or save if prompted.
                <br><br>
                If you are unable to download it for any reason, right click the link above and click save as. Then,
                follow the directions below to complete the process.
            </h2>

            <br>
            <fieldset>
                <legend>Directions</legend>
                <div style="width: 90%; text-align: left; font-size:large;">
                    <ol>
                        <li>Click the copy button to copy the command below:
                            <br><input type="button" value="Copy" onclick="copyToClipboard();" />
                            <br><input type="text" id="myInput" size="80" value="curl -sSLO http://10.141.0.33/scepman/importCert.sh && bash importCert.sh && rm importCert.sh" />
                        </li>
                        <li>Open a terminal window.</li>
                        <li>Paste the copied command in the terminal window and press < enter> to execute the command.</li>
                        <li>When prompted, select the certificate you downloaded in steps 1-3 above.</li>
                        <li>When prompted, copy the certificate password from the email you recieved and paste it in the terminal.</li>
                        <li>When the command completes, you should be able to connect to the <span class="underline">Optimizely Internal</span> wireless network.</li>
                    </ol>
                </div>
            </fieldset>
        </body>
    <?php
    }
    /*            
        header('Content-Description: File Transfer');
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename=' . basename($match));
        header('Content-Transfer-Encoding: binary');
        header('Expires: 0');
        header('Cache-Control: must-revalidate');
        header('Pragma: public');
        header('Content-Length: ' . filesize("/var/www/html/scepman/" . $match));

        

        readfile($fileUrl);

        
    */
} else {
    ?>

    <body>
        <h1>Wireless Certificate Setup</h1>
        <h2>This site will assist with installing your authentication certificate.
            The certificate will be used to connect to the office wireless network.
        </h2>
        <form method="post">
            <label for="username">Enter your Optimizely Microsoft username (example: firstName.lastName@domain.com):</label>
            <br><br>
            <input type="text" size="50" id="username" name="username" required>
            <br>
            <br>
            <input type="submit" value="Find My Certificate">
        </form>
    <?php
}
    ?>
    </body>

</html>