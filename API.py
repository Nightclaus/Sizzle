import what3words
import os

geocoder = what3words.Geocoder(os.environ.get('W3W_API_KEY'))

res = geocoder.convert_to_coordinates('prom.cape.pump')
print(res)