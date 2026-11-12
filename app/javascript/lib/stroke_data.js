export function strokeData(url) {
  return () =>
    fetch(url).then((response) => {
      if (!response.ok) throw new Error(`Stroke data ${response.status}`);
      return response.json();
    });
}
