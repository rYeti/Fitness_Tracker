using System.Text.Json;
using System.Text.Json.Serialization;

namespace FitTracker.Api.DTOs;

/// <summary>
/// One entry of <c>POST api/ScheduledWorkout/{id}/exercises/batch</c>: a session exercise
/// to create for a workout exercise.
/// </summary>
/// <remarks>
/// Shipped apps send the batch as a bare array of workout-exercise ids. Apps that mint
/// their own ids send objects, <c>{ "id": …, "workoutExerciseId": … }</c>. The endpoint
/// takes either, element by element (<see cref="Converter"/>), so neither generation of
/// the app needs a route of its own.
/// </remarks>
[JsonConverter(typeof(Converter))]
public class ScheduledExerciseBatchItemDto
{
    /// <summary>The id the app minted for the session exercise, if it sent one.</summary>
    public Guid? Id { get; set; }

    /// <summary>The workout exercise this session exercise performs.</summary>
    public Guid WorkoutExerciseId { get; set; }

    /// <summary>Reads a bare id string as an item without an id of its own.</summary>
    public sealed class Converter : JsonConverter<ScheduledExerciseBatchItemDto>
    {
        /// <inheritdoc/>
        public override ScheduledExerciseBatchItemDto Read(
            ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.String)
            {
                return new ScheduledExerciseBatchItemDto { WorkoutExerciseId = reader.GetGuid() };
            }
            if (reader.TokenType != JsonTokenType.StartObject)
            {
                throw new JsonException("Expected a workout exercise id or an object.");
            }

            var item = new ScheduledExerciseBatchItemDto();
            while (reader.Read() && reader.TokenType != JsonTokenType.EndObject)
            {
                var name = reader.GetString();
                reader.Read();
                if (string.Equals(name, "id", StringComparison.OrdinalIgnoreCase))
                {
                    item.Id = reader.TokenType == JsonTokenType.Null ? null : reader.GetGuid();
                }
                else if (string.Equals(name, "workoutExerciseId", StringComparison.OrdinalIgnoreCase))
                {
                    item.WorkoutExerciseId = reader.GetGuid();
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
            Utf8JsonWriter writer, ScheduledExerciseBatchItemDto value, JsonSerializerOptions options)
        {
            writer.WriteStartObject();
            if (value.Id is { } id) writer.WriteString("id", id);
            else writer.WriteNull("id");
            writer.WriteString("workoutExerciseId", value.WorkoutExerciseId);
            writer.WriteEndObject();
        }
    }
}
