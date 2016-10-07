Welcome to the composer demo.

<form action="/api/v0/compose" method="POST">
     <select name="module[]" multiple>
%for module in modules:
         <option value=${module}>${module}</option>
%endfor
     </select>
     <input type="hidden" name="type" value="iso">
     <input type="submit" value="BIG RED BUTTON">
</form>

<form action="/api/v0/compose/cancel" method="POST">
     <input type="submit" value="CANCEL COMPOSE">
</form>

<div>
Test recipe creation
<form action="/api/v0/recipe/test" method="POST">
    <textarea name="recipe" cols="40" rows="20"></textarea>
    <input type="submit" value="Save Recipe">
</form>
</div>
