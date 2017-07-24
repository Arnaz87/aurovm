// Pequeño algoritmo para averiguar cuál es el formato de código más corto

List<Int> quickSort(List<Int> arr) {
  if (!arr.isEmpty()) {
    int pivot = arr.get(0); //This pivot can change to get faster results

    List<Int> less = new List<Int>();
    List<Int> more = new List<Int>();

    // Partition
    int length = arr.length;
    for (int n : arr) {
      int n = arr.get(i);
      if (n <= pivot) less.add(n);
      else more.add(n);
    }

    // Recursively sort sublists
    less = quickSort(less);
    more = quickSort(more);
    
    // Concatenate results
    less.addAll(more);
    return less;
  }
  return arr;
}