"""
California License Plate Validator
Supports multiple plate formats from 1914 to present
"""
import re
import random

class CaliforniaPlateValidator:
    def __init__(self):
        self.plate_formats = {
            # Historical formats (1914-1969)
            "1914-1920": [r'^\d{1,5}$'],  # 1-5 digits
            "1920-1928": [r'^\d{3} \d{3}$', r'^\d{6}$'],  # 123 456 or 123456
            "1929-1934": [r'^[A-Z]{3}-\d{3}$'],  # ABC-123
            "1935-1956": [r'^\d{1,3}[A-Z]{1,3}$', r'^[A-Z]{1,3}\d{1,3}$'],  # 123ABC or ABC123
            
            # Modern formats (1956-present)
            "1956-1969": [r'^[A-Z]{3} \d{3}$'],  # ABC 123
            "1970-1980": [r'^\d{3} [A-Z]{3}$'],  # 123 ABC
            "1981-2000": [r'^[1-9][A-Z]{3}\d{3}$'],  # 1ABC123 (no leading 0)
            "2001-present": [
                r'^[1-9][A-Z]{3}\d{3}$',  # Standard: 1ABC123
                r'^[A-Z]{2}\d{3}[A-Z]{2}$',  # Commercial: AB123CD
                r'^[A-Z]{1,7}$',  # Personalized: CALIFORNIA
                r'^[A-Z]{3}\d{4}$',  # Motorcycle: ABC1234
                r'^[A-Z]{1}\d{6}$',  # 1963 series: A123456
                r'^\d{7}$',  # All numeric: 1234567
            ],
            
            # Special series
            "legislative": [r'^S\d{6}$'],  # Legislative: S123456
            "exempt": [r'^E\d{6}$'],  # Exempt: E123456
            "livery": [r'^L\d{6}$'],  # Livery: L123456
        }
        
        self.sample_plates = [
            # Modern plates (2001-present)
            "1ABC123", "7XYZ789", "2DEF456", "8GHI012",
            "AB123CD", "XY789ZW", "LM456NO", "PQ901RS",
            "CALIFORNIA", "SUNSHINE", "COASTER", "SURFER",
            "ABC1234", "XYZ5678", "MNO9012", "PQR3456",
            "A123456", "B789012", "C345678", "D901234",
            "1234567", "8901234", "5678901", "2345678",
            
            # Vintage plates
            "123456", "ABC-123", "ABC 123", "123 ABC",
            
            # Special plates
            "S123456", "E789012", "L345678"
        ]

    def validate_plate(self, plate_number):
        """
        Validate California license plate number
        Returns: (is_valid, format_type, message)
        """
        if not plate_number:
            return False, "Invalid", "Plate number cannot be empty"
        
        # Clean input
        plate = plate_number.strip().upper()
        
        # Remove spaces and hyphens for validation
        clean_plate = plate.replace(" ", "").replace("-", "")
        
        # Basic checks
        if len(clean_plate) < 1 or len(clean_plate) > 7:
            return False, "Invalid", "Plate must be 1-7 characters"
        
        # Check each format
        for era, patterns in self.plate_formats.items():
            for pattern in patterns:
                # For patterns with spaces/hyphens, use original plate
                if " " in pattern or "-" in pattern:
                    if re.match(pattern, plate):
                        return True, era, f"Valid {era} format"
                # For patterns without spaces/hyphens, use cleaned plate
                elif re.match(pattern, clean_plate):
                    return True, era, f"Valid {era} format"
        
        return False, "Invalid", "Does not match any California plate format"

    def generate_random_plate(self):
        """Generate a random California plate number"""
        import random
        return random.choice(self.sample_plates)

    def get_plate_info(self, plate_number):
        """Get detailed information about a plate"""
        is_valid, format_type, message = self.validate_plate(plate_number)
        
        info = {
            "plate": plate_number,
            "is_valid": is_valid,
            "format_type": format_type,
            "message": message,
            "character_count": len(plate_number.replace(" ", "").replace("-", "")),
            "has_special_chars": any(c in plate_number for c in " -"),
            "suggested_correction": None
        }
        
        # Suggest corrections for common mistakes
        if not is_valid:
            clean_plate = plate_number.strip().upper().replace("O", "0").replace("I", "1")
            if clean_plate != plate_number:
                info["suggested_correction"] = clean_plate
        
        return info

# Singleton instance
validator = CaliforniaPlateValidator()