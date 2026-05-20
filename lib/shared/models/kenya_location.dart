class KenyaCounty {
  const KenyaCounty({
    required this.id,
    required this.name,
    required this.subcounties,
  });

  final int id;
  final String name;
  final List<KenyaSubcounty> subcounties;
}

class KenyaSubcounty {
  const KenyaSubcounty({required this.id, required this.name});

  final int id;
  final String name;
}

const kenyaCounties = [
  KenyaCounty(
    id: 30,
    name: 'Nairobi',
    subcounties: [
      KenyaSubcounty(id: 301, name: 'Westlands'),
      KenyaSubcounty(id: 302, name: 'Kasarani'),
      KenyaSubcounty(id: 303, name: 'Embakasi East'),
    ],
  ),
  KenyaCounty(
    id: 1,
    name: 'Mombasa',
    subcounties: [
      KenyaSubcounty(id: 101, name: 'Changamwe'),
      KenyaSubcounty(id: 102, name: 'Likoni'),
      KenyaSubcounty(id: 103, name: 'Nyali'),
    ],
  ),
  KenyaCounty(
    id: 22,
    name: 'Kiambu',
    subcounties: [
      KenyaSubcounty(id: 221, name: 'Thika Town'),
      KenyaSubcounty(id: 222, name: 'Ruiru'),
      KenyaSubcounty(id: 223, name: 'Kikuyu'),
    ],
  ),
];
