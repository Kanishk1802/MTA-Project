<script>
    export let name = "York Street"; // Default value
    export let grade = "B"; // Default value

    // Define grade colors
    const gradeColors = {
        'A': 'bg-green-500',
        'B': 'bg-green-400',
        'C': 'bg-yellow-400',
        'D': 'bg-orange-400',
        'F': 'bg-red-500'
    };
</script>

<div class="flex items-center justify-between p-4 border-b border-gray-300">
    <!-- Title Section -->
    <div class="text-2xl font-bold text-gray-800">
        {name}
    </div>

    <!-- Grade Section -->
    <div class={`w-10 h-10 flex items-center justify-center text-lg font-semibold text-white rounded-md ${gradeColors[grade] || 'bg-gray-300'}`}>
        {grade}
    </div>
</div>