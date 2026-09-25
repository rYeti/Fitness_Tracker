using System.Text.Json;
using System.Text.Json.Serialization;

namespace FitTracker.Api.DTOs;

/// <summary>
/// One entry of <c>POST api/Meal/{id}/foods/batch</c>: a food to put in the meal.
/// </summary>
/// <remarks>
/// Shipped apps send the batch as a bare array of food item ids, and each one is a new
/// entry. Apps that mint their own ids send objects, <c>{ "id": …, "foodItemId": … }</c>,
/// and the batch is then an upsert: an id the caller already holds is that entry again —
/// given the food sent, and moved into this meal if it sat in another of the caller's —
/// and a new one is stored under it. The endpoint takes either shape, element by element
/// (<see cref="Converter"/>), the way the session-exercise batch does, so neither
/// generation of the app needs a route of its own.
/// </remarks>
[JsonConverter(typeof(Converter))]
public class MealFoodEntryRequestDto
{
    /// <summary>
    /// The id the app minted for this entry. Absent, the server mints one. An id that
    /// names an entry in someone else's meal is refused with 409.
    /// </summary>
    public Guid? Id { get; set; }

    /// <summary>The client-side ID of the food item to link.</summary>
    public Guid FoodItemId { get; set; }

    /// <summary>Reads a bare id string as an entry without an id of its own.</summary>
    public sealed class Converter : JsonConverter<MealFoodEntryRequestDto>
    {
        /// <inheritdoc/>
        public override MealFoodEntryRequestDto Read(
            ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.String)
            {
                return new MealFoodEntryRequestDto { FoodItemId = reader.GetGuid() };
            }
            if (reader.TokenType != JsonTokenType.StartObject)
            {
                throw new JsonException("Expected a food item id or an object.");
            }

            var item = new MealFoodEntryRequestDto();
            while (reader.Read() && reader.TokenType != JsonTokenType.EndObject)
            {
                var name = reader.GetString();
                reader.Read();
                if (string.Equals(name, "id", StringComparison.OrdinalIgnoreCase))
                {
                    item.Id = reader.TokenType == JsonTokenType.Null ? null : reader.GetGuid();
                }
                else if (string.Equals(name, "foodItemId", StringComparison.OrdinalIgnoreCase))
                {
                    item.FoodItemId = reader.GetGuid();
                }
                else
                {
                    reader.Skip();
                }
            }
            return item;
        }

        /// <inheritdoc/>
        public override void Write(
            Utf8JsonWriter writer, MealFoodEntryRequestDto value, JsonSerializerOptions options)
        {
            writer.WriteStartObject();
            if (value.Id is { } id) writer.WriteString("id", id);
            else writer.WriteNull("id");
            writer.WriteString("foodItemId", value.FoodItemId);
            writer.WriteEndObject();
        }
    }
}
