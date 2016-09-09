Welcome to the composer demo.

<form action="/api/v0/compose" method="POST">
     <select name="module">
%for module in modules:
         <option value=${module}>${module}</option>
%endfor
     </select>
     <input type="submit" value="BIG RED BUTTON">
</form>
