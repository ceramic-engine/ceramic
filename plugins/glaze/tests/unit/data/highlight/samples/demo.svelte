<script lang="ts">
  export let name: string = "world";
  let count = 0;
</script>

<button on:click={() => count++}>Hello {name}! {count}</button>

<style>
  button { color: #ff3e00; }
</style>
