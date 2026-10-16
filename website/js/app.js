const properties = [
  {
    name: "The Azure Estate",
    location: "Miami, Florida",
    price: "$18,500,000",
    beds: 7,
    baths: 9,
    image: "images/miami.jpg"
  },
  {
    name: "The Manhattan Crown",
    location: "New York, New York",
    price: "$12,750,000",
    beds: 5,
    baths: 6,
    image: "images/penthouse.jpg"
  },
  {
    name: "The Golden Villa",
    location: "Beverly Hills, California",
    price: "$24,900,000",
    beds: 8,
    baths: 11,
    image: "images/beverly-hills.jpg"
  }
];

const propertyList = document.getElementById("property-list");

properties.forEach(property => {
  propertyList.innerHTML += `
    <div class="property-card">
      <img src="${property.image}" alt="${property.name}">
      <div class="details">
        <h3>${property.name}</h3>
        <div class="price">${property.price}</div>
        <p>${property.location}</p>
        <p>${property.beds} Bedrooms | ${property.baths} Bathrooms</p>
      </div>
    </div>
  `;
});
