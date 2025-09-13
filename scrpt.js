function generateSH() {
    var name = document.getElementById("name").value;
    var content = "#!/bin/bash\n";
    content += "echo 'Hello, " + name + "! This is your generated SH file.'";

    var blob = new Blob([content], { type: "text/plain" });
    var url = URL.createObjectURL(blob);

    var a = document.createElement("a");
    a.href = url;
    a.download = "hello.sh";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
}
